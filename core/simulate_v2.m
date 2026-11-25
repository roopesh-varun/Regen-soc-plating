function [M, L] = simulate_v2(cfg)
%SIMULATE_V2  Ns drive-cycle runs at once. Each sample: a pack of N series cells
%   (reduced physics model with cell-to-cell spread), a BMS (circuit model + EKF +
%   anode-potential plating limit) and one charge-limit policy.
%   Signal chain each step (all samples in parallel):
%     drive cycle -> vehicle -> BMS limit (from ESTIMATED states) -> protection on
%     MEASURED voltage (delayed) -> true cells -> sensors -> EKF and BMS anode states.
rng(cfg.seed);
P = cell_params(); veh = params_vehicle_v2();
[t, v, grade] = drive_cycle(cfg.cycle, cfg.dt, cfg.cycle_opts);
dt = cfg.dt; K = numel(t); Ns = cfg.Ns; N = cfg.N;
a = [diff(v) / dt; 0]; v_mid = [(v(1:end-1) + v(2:end)) / 2; v(end)];
col = @(x) x(:) .* ones(Ns, 1);
soc0 = col(cfg.soc0); Tamb = col(cfg.T_amb_C) + 273.15;
age = struct('soh', col(cfg.age.soh), 'rscale', col(cfg.age.rscale), 'kscale', col(cfg.age.kscale));
[C, dz, dTc] = pack_sample(Ns, N, cfg.spread, age);
Tcell_amb = Tamb + dTc;                                   % each cell's coolant temperature
X = cell_init(P, min(max(soc0 + dz, 0.01), 0.995), Tcell_amb, C);
zc0 = min(max(soc0 + dz, 0.01), 0.995);
ceilc = max(P.z_ceil, zc0);                        % a cell already above the ceiling may not rise further
ns_pack = veh.ns;                                        % electrical pack size (96 cells)
pol = upper(cfg.policy);
% ---- sensors: module temperature sensors
nmod = ceil(N / cfg.cells_per_sensor);
modid = min(ceil((1:N) / cfg.cells_per_sensor), nmod);
% ---- BMS
z0e = min(max(soc0 + col(cfg.z0_err), 0), 1);
E = ekf_init_v2(z0e, col(cfg.bms_Q), col(cfg.bms_Rs), col(cfg.ocv_off), cfg.ekf_P0, Ns);
B.qn = zeros(Ns, 1); B.ve = zeros(Ns, 1);
Bw = B;                                           % ROBUSTA: transient states of the statistically worst cell
RC.v1 = zeros(Ns, 1); RC.v2 = zeros(Ns, 1);       % open-loop RC states (BIAS / TRUE modes)
I_off = col(cfg.I_off); bias = col(cfg.bias);
bkf = col(cfg.bms_kf); brf = col(cfg.bms_rf);   % kinetic / resistance factors the BMS believes
% first measurements (at rest)
Vm = ocv_now(X, P) + cfg.V_noise * randn(Ns, N);
Vmean = mean(Vm, 2); Vmaxm = max(Vm, [], 2);
Im = I_off + cfg.I_noise * randn(Ns, 1);
Tsens = sensor_T(X.T, modid, nmod, cfg.T_noise);
% key-on spread estimate (ROBUSTA): highest cell above mean, via the OCV slope
dU0 = max(ulerp(P.docv, E.z), 0.05);
spread_est = min(max((Vmaxm - Vmean) ./ dU0, 0), 0.05);
nd = max(round(cfg.prot_delay / dt), 0);
Ibuf = P.I_hw * ones(Ns, nd + 1);
% ---- metrics accumulators
o = zeros(Ns, 1);
M = struct('E_avail', o, 'E_regen', o, 'E_fric', o, 'E_brake', o, 'E_drive', o, ...
    't_ceil', o, 'zmax', o, 'phimin', 0.2 + o, 't_plate', o, 'Qpl', o, ...
    'err_mean', o, 'err_max', o, 'err_min', o, 't_clip', o);
M.err_min = 1 + o; M.err_max = -1 + o;
if cfg.log
    li = cfg.log_idx; nl = numel(li); Z = zeros(K, nl);
    L = struct('t', t, 'v', v, 'zbar', Z, 'zmaxc', Z, 'zest', Z, 'zp', Z, 'I', Z, 'Ilim', Z, ...
        'Ipl', Z, 'phimin', Z, 'P_avail', zeros(K, 1), 'P_bat', Z, 'T', Z, 'sig', Z);
else
    L = [];
end
zbar = soc0;
for k = 1:K
    [P_wheel, P_avail, P_brake] = vehicle_step(v_mid(k), a(k), grade(k), veh);
    Vpack = Vmean * ns_pack;
    % ---- SoC the BMS uses
    switch upper(cfg.est)
        case 'BIAS', zh = min(max(zbar + bias, 0), 1); sig = col(cfg.sigma_declared); v1 = RC.v1; v2 = RC.v2;
        case 'TRUE', zh = zbar; sig = 0 * o; v1 = RC.v1; v2 = RC.v2;
        otherwise,  zh = E.z; sig = E.sig; v1 = E.v1; v2 = E.v2;
    end
    Ilim = P.I_hw + o; Ipl = Ilim;
    if P_wheel >= 0
        P_cmd = -(P_wheel / (veh.eta_gear * veh.eta_mot) + veh.P_aux) + o;
    else
        Tpl = min(Tsens, [], 2) + 273.15;                % coldest sensor for plating
        Tav = mean(Tsens, 2);
        switch pol
            case 'SOP',      zp = zh;
            case 'ROBUST',   zp = zh + cfg.k * (sig + cfg.sigma_model);
            case 'ROBUSTA',  zp = zh + cfg.kA * (sig .* sqrt(max(E.nis, 1)) + cfg.sigma_model) + spread_est;
            case 'SOPM',     zp = zh;
            case 'LEANHIGH', zh = min(zh + cfg.lean, 1); zp = zh;
            otherwise,       zp = zh;
        end
        zp = min(max(zp, 0), 1);
        % voltage limit (circuit model, 10 s), referred to the highest measured cell
        [R0, R1, t1, R2, t2] = ecm_lookup(P, zh, Tav);
        R0 = R0 .* E.Rs; R1 = R1 .* E.Rs; R2 = R2 .* E.Rs;
        e1 = exp(-cfg.H ./ t1); e2 = exp(-cfg.H ./ t2);
        dU = max(ulerp(P.docv, zh), 0);
        IV = (P.Vmax - ulerp(P.ocv, zh) - E.ocv_off - (Vmaxm - Vmean) - v1 .* e1 - v2 .* e2) ./ ...
             (dU * cfg.H ./ (3600 * E.Q) + R1 .* (1 - e1) + R2 .* (1 - e2) + R0);
        if strcmp(pol, 'ORACLE')
            zc = (X.cn / P.neg.cmax - P.x0) / (P.x100 - P.x0);
            Iz = min((P.z_ceil - zc) .* (3600 * P.Q * C.capf) / cfg.H, [], 2);
            % plating limit of the true cells: rank every cell by its predicted potential
            % at a test current, then solve exactly for the 4 most exposed cells
            phit = anode_predict(P, X.cn / P.neg.cmax, X.qn, X.ve, 0.3 * P.Q + 0 * X.cn, X.T, cfg.H, C.capf, C.kf, C.rf);
            [~, ix] = sort(phit, 2); ix = ix(:, 1:min(4, N));
            rows = repmat((1:Ns)', 1, size(ix, 2)); id = sub2ind([Ns N], rows, ix);
            Ipl = min(plating_limit_v2(P, X.cn(id) / P.neg.cmax, X.qn(id), X.ve(id), X.T(id), ...
                cfg.H, cfg.phi_target, P.I_hw, C.capf(id), C.kf(id), C.rf(id)), [], 2);
        else
            Iz = (P.z_ceil - zp) * 3600 .* E.Q / cfg.H;
            xa = P.x0 + zp * (P.x100 - P.x0);
            target = cfg.phi_target; kfp = bkf; rfp = brf; capfp = E.Q / P.Q; Tp = Tpl;   % BMS's SoH estimate scales electrode area
            if strcmp(pol, 'SOPM'), target = cfg.phi_target + cfg.phi_margin; end
            if strcmp(pol, 'ROBUSTA')
                % statistically worst cell from the pack's known spread (end-of-line data)
                Ipl = plating_limit_worst(P, xa, Bw.qn, Bw.ve, Tp, cfg.H, target, P.I_hw, capfp, kfp, rfp, cfg.bms_spread, cfg.kc);
            else
                Ipl = plating_limit_v2(P, xa, B.qn, B.ve, Tp, cfg.H, target, P.I_hw, capfp, kfp, rfp);
            end
        end
        Ilim = max(0, min(min(min(P.I_hw, IV), Iz), Ipl));
        P_lim = Ilim .* Vpack;
        P_req = min(P_avail, P_lim + veh.P_aux);
        P_cmd = P_req - veh.P_aux;
    end
    % ---- inverter current command and protection (measured, delayed)
    I_cmd = P_cmd ./ Vpack;
    R0b = ecm_lookup(P, zh, mean(Tsens, 2));
    Iadm = max(0, (P.Vmax - (Vmaxm - R0b .* Im)) ./ R0b);
    Iadm(min(Tsens, [], 2) < 0) = 0;
    Iadm = min(Iadm, P.I_hw);
    Ibuf = [Ibuf(:, 2:end), Iadm];
    I_act = min(I_cmd, Ibuf(:, 1));
    clip = I_cmd > Ibuf(:, 1);
    % ---- true cells
    [X, V, phi] = cell_step(X, I_act, dt, P, C, Tcell_amb);
    zc = (X.cn / P.neg.cmax - P.x0) / (P.x100 - P.x0);
    zbar = mean(zc, 2);
    P_bat = I_act .* mean(V, 2) * ns_pack;               % W, + = charging
    if P_brake > 0
        regen = min(max(P_bat + veh.P_aux, 0), P_avail);
        M.E_fric = M.E_fric + max(P_brake - regen / (veh.eta_mot * veh.eta_gear), 0) * dt;
        M.E_regen = M.E_regen + regen * dt;
        M.E_avail = M.E_avail + P_avail * dt;
        M.E_brake = M.E_brake + P_brake * dt;
    else
        M.E_drive = M.E_drive + max(-P_bat, 0) * dt;
    end
    % ---- sensors and BMS updates
    Vm = V + cfg.V_noise * randn(Ns, N);
    Vmean = mean(Vm, 2); Vmaxm = max(Vm, [], 2);
    Im = I_act + I_off + cfg.I_noise * randn(Ns, 1);
    Tsens = sensor_T(X.T, modid, nmod, cfg.T_noise);
    E = ekf_step_v2(E, Im, Vmean, mean(Tsens, 2), dt, P, cfg);
    [~, R1o, t1o, R2o, t2o] = ecm_lookup(P, zh, mean(Tsens, 2));
    a1o = exp(-dt ./ t1o); a2o = exp(-dt ./ t2o);
    RC.v1 = a1o .* RC.v1 + R1o .* (1 - a1o) .* Im; RC.v2 = a2o .* RC.v2 + R2o .* (1 - a2o) .* Im;
    B = bms_anode_step(B, Im ./ (E.Q / P.Q), min(Tsens, [], 2) + 273.15, dt, P);
    if strcmp(pol, 'ROBUSTA')   % worst cell: colder and smaller than the coldest sensor's average cell
        sb = cfg.bms_spread;
        Bw = bms_anode_step(Bw, Im ./ (E.Q / P.Q) / (1 - cfg.kc * sb.cap), min(Tsens, [], 2) + 273.15 - cfg.kc * sb.T, dt, P);
    end
    % ---- metrics
    zmx = max(zc, [], 2); phm = min(phi, [], 2);
    M.t_ceil = M.t_ceil + dt * any(zc > ceilc + 1e-4, 2);
    M.zmax = max(M.zmax, zmx);
    M.phimin = min(M.phimin, phm);
    M.t_plate = M.t_plate + dt * (phm < 0);
    M.t_clip = M.t_clip + dt * clip;
    err = zh - zbar;
    M.err_mean = M.err_mean + err / K;
    M.err_max = max(M.err_max, err); M.err_min = min(M.err_min, err);
    if cfg.log
        L.zbar(k, :) = zbar(li); L.zmaxc(k, :) = zmx(li); L.zest(k, :) = zh(li);
        if P_wheel < 0, L.zp(k, :) = zp(li); else, L.zp(k, :) = NaN; end
        L.I(k, :) = I_act(li); L.Ilim(k, :) = Ilim(li); L.Ipl(k, :) = Ipl(li);
        L.phimin(k, :) = phm(li); L.P_avail(k) = P_avail * (P_brake > 0); L.P_bat(k, :) = P_bat(li);
        L.T(k, :) = mean(X.T(li, :), 2)' - 273.15; L.sig(k, :) = sig(li);
    end
end
M.Qpl = max(X.Qpl, [], 2);
M.zend = zbar; M.zest_end = zh;
for f = {'E_avail', 'E_regen', 'E_fric', 'E_brake', 'E_drive'}
    M.(f{1}) = M.(f{1}) / 3.6e6;                         % kWh
end
M.phimin = 1e3 * M.phimin;                               % mV
M.breach_pl = M.phimin < -0.1;                          % 0.1 mV tolerance = resolution of the limit search
M.breach_ceil = M.t_ceil > 0;
end

function U = ocv_now(X, P)
U = up_ocp(X.cp / P.pos.cmax) - ulerp(P.Un, X.cn / P.neg.cmax);
end

function Ts = sensor_T(T, modid, nmod, noise)
[Ns, ~] = size(T); Ts = zeros(Ns, nmod);
for m = 1:nmod
    Ts(:, m) = mean(T(:, modid == m), 2);
end
Ts = Ts - 273.15 + noise * randn(Ns, nmod);
end

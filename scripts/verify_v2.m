%VERIFY_V2  Checks on the v2 model. Prints PASS/FAIL for each and writes results/verify_v2.txt.
root = fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root, 'core')); addpath(fullfile(root, 'scripts')); cd(root);
if ~exist('results', 'dir'), mkdir('results'); end
fid = fopen(fullfile('results', 'verify_v2.txt'), 'w');
rep = @(id, ok, msg) vreport(fid, id, ok, msg);
P = cell_params(); C1 = struct('capf', 1, 'rf', 1, 'kf', 1);

% V1 charge balance of the true cell: SoC change equals Ah in / capacity
X = cell_init(P, 0.5, 298.15, C1); n = 3000; dt = 0.2;
for k = 1:n, X = cell_step(X, 86, dt, P, C1, 298.15); end
z1 = (X.cn / P.neg.cmax - P.x0) / (P.x100 - P.x0);
zc = 0.5 + 86 * n * dt / (3600 * 86);
rep('V1', abs(z1 - zc) < 1e-6, sprintf('1C for 600 s from 50%%: SoC %.6f vs Coulomb count %.6f (difference %.1e)', z1, zc, abs(z1 - zc)));

% V2 MATLAB reduced model = Python reduced model used for fitting (two DFN validation cases)
tags = {'val_HARDSTOP_E3_T10_S92', 'val_hill95_bias+0_T25_S90'}; Tt = [10 25]; Zt = [0.92 0.90]; worst = 0;
for i = 1:2
    r = csvread(fullfile(root, 'pyref', 'dfn_data', [tags{i} '_reduced.csv']), 1, 0);
    X = cell_init(P, Zt(i), Tt(i) + 273.15, C1); ph = zeros(size(r, 1), 1);
    for k = 1:size(r, 1)
        dtk = 0; if k > 1, dtk = r(k, 1) - r(k - 1, 1); end
        Tk = X.T; [X, ~, ph(k)] = cell_step(X, r(k, 2) * P.S, dtk, P, C1, Tk); X.T = Tk;
    end
    worst = max(worst, max(abs(ph - r(:, 6))));
end
rep('V2', worst < 2e-4, sprintf('max |phi MATLAB - phi Python| = %.3f mV', 1e3 * worst));

% V3 reduced model vs DFN (from pyref/validate_reduced.py): lowest anode potential within 5 mV
txt = fileread(fullfile(root, 'pyref', 'dfn_data', 'validation.json'));
td = regexp(txt, '"minPhiDFN_mV": ([-0-9.e]+)', 'tokens'); tr = regexp(txt, '"minPhiRed_mV": ([-0-9.e]+)', 'tokens');
mins_d = cellfun(@(c) str2double(c{1}), td); mins_r = cellfun(@(c) str2double(c{1}), tr);
rep('V3', max(abs(mins_d - mins_r)) < 5, sprintf('lowest anode potential, reduced vs DFN: max difference %.1f mV over %d drive profiles', max(abs(mins_d - mins_r)), numel(mins_d)));

% V4 time-step convergence (regen energy, hard stops, 10 C, 90 %)
cfg = default_cfg_v2(); cfg.est = 'TRUE'; cfg.soc0 = 0.9; cfg.T_amb_C = 10;
cfg.dt = 0.2; M1 = simulate_v2(cfg); cfg.dt = 0.05; M2 = simulate_v2(cfg);
d = abs(M1.E_regen - M2.E_regen) / M2.E_regen;
rep('V4', d < 0.01, sprintf('regen energy dt 0.2 s vs 0.05 s: %.2f %% difference', 100 * d));

% V5 the oracle never plates or passes the ceiling (96-cell packs, three cycles, cold and warm)
cfg = default_cfg_v2(); cfg.policy = 'ORACLE'; cfg.N = 96; cfg.Ns = 30; cfg.est = 'TRUE';
nb = 0; mn = inf; tot = 0;
cyc = {'HARDSTOP', 'HILL'}; opt = {struct('decel', 3), struct()};
for c = 1:2
    for T = [10 25]
        cfg.cycle = cyc{c}; cfg.cycle_opts = opt{c}; cfg.T_amb_C = T; cfg.soc0 = 0.93;
        M = simulate_v2(cfg); nb = nb + sum(M.breach_pl | M.breach_ceil); mn = min(mn, min(M.phimin)); tot = tot + cfg.Ns;
    end
end
rep('V5', nb == 0, sprintf('oracle: %d breaches in %d pack runs, lowest anode potential %.1f mV', nb, tot, mn));

% V6 a single nominal cell with a perfect SoC under SOP does not plate
cfg = default_cfg_v2(); cfg.est = 'TRUE'; cfg.Ns = 3; cfg.soc0 = [0.8 0.9 0.95]'; nb = 0; mn = inf;
for T = [10 25 40]
    cfg.T_amb_C = T; M = simulate_v2(cfg); nb = nb + sum(M.breach_pl); mn = min(mn, min(M.phimin));
end
rep('V6', nb == 0, sprintf('SOP, perfect SoC, one cell: %d plating breaches in 9 runs (lowest %.1f mV)', nb, mn));

% V7 monotone response to a constant SoC bias (95 % start, 25 C)
cfg = default_cfg_v2(); cfg.est = 'BIAS'; cfg.bias = (-0.05:0.01:0.05)'; cfg.Ns = 11; cfg.soc0 = 0.95; cfg.T_amb_C = 25;
M = simulate_v2(cfg);
ok = all(diff(M.E_regen) <= 1e-6) && all(diff(M.phimin) >= -0.05);
rep('V7', ok, sprintf('regen falls and anode margin rises as the bias goes from -5 %% to +5 %% (regen %.3f -> %.3f kWh)', M.E_regen(1), M.E_regen(end)));

% V8 EKF converges from a 3 % initial error on MIDC (nominal fresh cell, 25 C)
cfg = default_cfg_v2(); cfg.cycle = 'MIDC'; cfg.cycle_opts = struct(); cfg.soc0 = 0.8; cfg.z0_err = 0.03; cfg.Ns = 1;
M = simulate_v2(cfg);
rep('V8', abs(M.zest_end - M.zend) < 0.015, sprintf('EKF error at end of MIDC: %.2f %% (started at +3 %%)', 100 * (M.zest_end - M.zend)));

% V9 energy bookkeeping: regen + friction (referred to the DC bus) = braking energy available
cfg = default_cfg_v2(); cfg.est = 'TRUE'; cfg.soc0 = 0.6; cfg.T_amb_C = 25; M = simulate_v2(cfg);
veh = params_vehicle_v2();
lhs = M.E_regen / (veh.eta_mot * veh.eta_gear) + M.E_fric;
rep('V9', abs(lhs - M.E_brake) / M.E_brake < 0.02, sprintf('braking energy %.3f kWh = regen %.3f (at wheel %.3f) + friction %.3f', M.E_brake, M.E_regen, M.E_regen / (veh.eta_mot * veh.eta_gear), M.E_fric));
fclose(fid);


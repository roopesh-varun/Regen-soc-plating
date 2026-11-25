%EXP_X5_MC  Monte Carlo: random trips, realistic EKF errors, 96-cell packs, six policies.
%   phase = 'train': ROBUSTA margin kA swept on training trips (seed 101) to pick the smallest
%                    kA with at most 1 % plating breaches.
%   phase = 'test' : every policy on independent test trips (seed 202) with that kA.
if ~exist('phase', 'var'), phase = 'train'; end
root = fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root, 'core')); addpath(fullfile(root, 'scripts')); cd(root);
Ns = 200;
cyc = {'HARDSTOP', 'MIDC', 'HILL'}; opt = {struct('decel', 2), struct(), struct()};
if strcmp(phase, 'train')
    seed = 101; runs = {{'ORACLE', 0}, {'ROBUSTA', 0}, {'ROBUSTA', 1}, {'ROBUSTA', 2}, {'ROBUSTA', 3}};
else
    seed = 202; kA = 0; if exist(fullfile('results', 'X5_kA.txt'), 'file'), kA = load(fullfile('results', 'X5_kA.txt')); end
    runs = {{'ORACLE', 0}, {'SOP', 0}, {'SOPM', 0}, {'ROBUST', 0}, {'LEANHIGH', 0}, {'ROBUSTA', kA}};
end
% optional: run only some of the runs (keeps their run numbers) and write to a tagged file
if ~exist('only', 'var'), only = 1:numel(runs); end
if ~exist('tag', 'var'), tag = ''; end
R = [];
for c = 1:numel(cyc)
    S = mc_sample(Ns, seed + c);
    for r = only
        cfg = default_cfg_v2(); cfg.N = 96; cfg.Ns = Ns; cfg.cycle = cyc{c}; cfg.cycle_opts = opt{c};
        cfg.policy = runs{r}{1}; cfg.kA = runs{r}{2}; cfg.seed = seed + 10 * c;
        cfg.T_amb_C = S.T_amb_C; cfg.soc0 = S.soc0;
        cfg.age = struct('soh', S.soh, 'rscale', S.rscale, 'kscale', S.kscale);
        cfg.bms_Q = S.bms_Q; cfg.bms_Rs = S.bms_Rs; cfg.bms_rf = S.bms_Rs; cfg.bms_kf = S.bms_kf;
        cfg.z0_err = S.z0_err; cfg.I_off = S.I_off; cfg.ocv_off = S.ocv_off;
        tic; M = simulate_v2(cfg); [nm, A] = metrics_row(M);
        R = [R; c * ones(Ns, 1), r * ones(Ns, 1), cfg.kA * ones(Ns, 1), (1:Ns)', S.T_amb_C, S.soc0, S.soh, S.z0_err, A]; %#ok<AGROW>
        fprintf('X5 %s %-8s %-8s kA=%.1f breach_pl %3d/%d ceil %3d regen %.3f kWh (%.0f s)\n', phase, cyc{c}, runs{r}{1}, cfg.kA, ...
            sum(M.breach_pl), Ns, sum(M.breach_ceil), mean(M.E_regen), toc);
        write_csv(fullfile('results', ['X5_' phase tag '.csv']), [{'cycle', 'run', 'kA', 'trip', 'T_amb', 'soc0', 'soh', 'z0_err'}, nm], R);
    end
end
if strcmp(phase, 'train') && any(only > 1)
    % smallest kA with <= 1 % plating or ceiling breaches over all training trips
    best = NaN;
    for kA = [0 1 2 3]
        m = R(:, 2) > 1 & R(:, 3) == kA;
        rate = mean(R(m, 8 + 8) < -0.1 | R(m, end));   % column 16 = phimin (0.1 mV tolerance)
        fprintf('kA = %d: breach rate %.2f %%\n', kA, 100 * rate);
        if isnan(best) && rate <= 0.01, best = kA; end
    end
    if isnan(best), best = 3; end
    fid = fopen(fullfile('results', 'X5_kA.txt'), 'w'); fprintf(fid, '%g\n', best); fclose(fid);
end

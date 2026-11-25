%EXP_X1_ACCURACY  Constant SoC bias on one nominal cell (SOP limit, hard stops at 2 m/s^2).
%   Bias -10 % to +10 % in 0.5 % steps x start SoC 50-95 % x 0, 10, 25, 40 C.
%   Used for the asymmetry figure and the accuracy map.
root = fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root, 'core')); cd(root);
out = fullfile('results', 'X1_accuracy.csv'); R = [];
[bb, ss] = ndgrid((-0.10:0.005:0.10)', (0.50:0.05:0.95)');
for T = [0 10 25 40]
    cfg = default_cfg_v2(); cfg.est = 'BIAS'; cfg.policy = 'SOP';
        cfg.V_noise = 0; cfg.I_noise = 0; cfg.T_noise = 0;   % noise-free: clean bias-vs-twin comparison
    cfg.cycle = 'HARDSTOP'; cfg.cycle_opts = struct('decel', 2);
    cfg.Ns = numel(bb); cfg.bias = bb(:); cfg.soc0 = ss(:); cfg.T_amb_C = T;
    tic; M = simulate_v2(cfg); [nm, A] = metrics_row(M);
    R = [R; T * ones(cfg.Ns, 1), bb(:), ss(:), A]; %#ok<AGROW>
    fprintf('X1 T=%d done in %.0f s\n', T, toc);
end
write_csv(out, [{'T', 'bias', 'soc0'}, nm], R);

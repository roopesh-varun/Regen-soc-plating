%EXP_X2_SCENARIOS  Constant SoC bias on one nominal cell across driving patterns.
root = fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root, 'core')); cd(root);
cyc = {'HARDSTOP', 'HARDSTOP', 'HARDSTOP', 'MIDC', 'HILL'};
opt = {struct('decel', 1), struct('decel', 2), struct('decel', 3), struct(), struct()};
lab = [1 2 3 4 5];   % 1-3 = hard stops at 1/2/3 m/s^2, 4 = MIDC, 5 = ghat descent
[bb, ss] = ndgrid([-0.05 -0.03 -0.02 -0.01 0 0.01 0.02 0.03 0.05]', [0.80 0.90 0.95]');
R = [];
for c = 1:numel(cyc)
    for T = [10 25 40]
        cfg = default_cfg_v2(); cfg.est = 'BIAS'; cfg.policy = 'SOP';
        cfg.V_noise = 0; cfg.I_noise = 0; cfg.T_noise = 0;   % noise-free: clean bias-vs-twin comparison
        cfg.cycle = cyc{c}; cfg.cycle_opts = opt{c};
        cfg.Ns = numel(bb); cfg.bias = bb(:); cfg.soc0 = ss(:); cfg.T_amb_C = T;
        tic; M = simulate_v2(cfg); [nm, A] = metrics_row(M);
        R = [R; lab(c) * ones(cfg.Ns, 1), T * ones(cfg.Ns, 1), bb(:), ss(:), A]; %#ok<AGROW>
        fprintf('X2 cycle %d T=%d done in %.0f s\n', c, T, toc);
    end
end
write_csv(fullfile('results', 'X2_scenarios.csv'), [{'cycle', 'T', 'bias', 'soc0'}, nm], R);

%EXP_X3_SPREAD  What cell-to-cell variation alone does (BMS knows the true mean SoC).
%   96-cell packs, 60 random packs per case, start 90 %, hard stops 2 m/s^2 and ghat descent.
root = fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root, 'core')); cd(root);
base = struct('cap', 0.01, 'R', 0.04, 'kin', 0.08, 'z', 0.01, 'T', 1.5);
cases = {}; labels = {};
for m = [0 0.5 1 2]
    s = base; f = fieldnames(s); for i = 1:numel(f), s.(f{i}) = m * s.(f{i}); end
    cases{end+1} = s; labels{end+1} = sprintf('all x%.1f', m); %#ok<AGROW>
end
f = fieldnames(base);
for i = 1:numel(f)
    s = base; for j = 1:numel(f), if j ~= i, s.(f{j}) = 0; end, end
    cases{end+1} = s; labels{end+1} = ['only ' f{i}]; %#ok<AGROW>
end
pols = {'SOP', 'SOPM', 'ROBUSTA', 'ORACLE'};
R = [];
for c = 1:numel(cases)
    for T = [10 25]
        for p = 1:numel(pols)
            if c > 4 && ~any(strcmp(pols{p}, {'SOP', 'ORACLE'})), continue; end
            cfg = default_cfg_v2(); cfg.N = 96; cfg.Ns = 60; cfg.est = 'TRUE'; cfg.kA = 0;
            cfg.spread = cases{c}; cfg.bms_spread = base; cfg.soc0 = 0.90; cfg.T_amb_C = T; cfg.policy = pols{p};
            cfg.seed = 7;
            tic; M = simulate_v2(cfg); [nm, A] = metrics_row(M);
            R = [R; c * ones(cfg.Ns, 1), T * ones(cfg.Ns, 1), p * ones(cfg.Ns, 1), (1:cfg.Ns)', A]; %#ok<AGROW>
            fprintf('X3 %-10s T=%d %-8s breach %2d/60 regen %.3f (%.0f s)\n', labels{c}, T, pols{p}, sum(M.breach_pl), mean(M.E_regen), toc);
        end
    end
end
write_csv(fullfile('results', 'X3_spread.csv'), [{'case', 'T', 'policy', 'pack'}, nm], R);
fid = fopen(fullfile('results', 'X3_labels.txt'), 'w'); fprintf(fid, '%s\n', labels{:}); fprintf(fid, 'policies: %s\n', strjoin(pols, ',')); fclose(fid);
% ghat descent, full spread, 10 and 25 C
R = [];
for T = [10 25]
    for p = 1:numel(pols)
        cfg = default_cfg_v2(); cfg.N = 96; cfg.Ns = 40; cfg.est = 'TRUE'; cfg.kA = 0; cfg.cycle = 'HILL'; cfg.cycle_opts = struct();
        cfg.soc0 = 0.85; cfg.T_amb_C = T; cfg.policy = pols{p}; cfg.seed = 7;
        tic; M = simulate_v2(cfg); [nm, A] = metrics_row(M);
        R = [R; T * ones(cfg.Ns, 1), p * ones(cfg.Ns, 1), (1:cfg.Ns)', A]; %#ok<AGROW>
        fprintf('X3 HILL T=%d %-8s breach %2d/40 regen %.3f (%.0f s)\n', T, pols{p}, sum(M.breach_pl), mean(M.E_regen), toc);
    end
end
write_csv(fullfile('results', 'X3_spread_hill.csv'), [{'T', 'policy', 'pack'}, nm], R);

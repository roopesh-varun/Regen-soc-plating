%EXP_X4_CASESTUDY  Time series for one aged pack, hard stops at 2 m/s^2 at 5 C, four policies.
%   The BMS tracks the pack's ageing (SoH 85 %) but its EKF starts 3 % low and its current sensor reads 0.5 A high.
root = fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root, 'core')); cd(root);
if ~exist('pols', 'var'), pols = {'SOP', 'ROBUST', 'ROBUSTA', 'ORACLE'}; end
for p = 1:numel(pols)
    cfg = default_cfg_v2(); cfg.N = 96; cfg.Ns = 1; cfg.cycle = 'HARDSTOP'; cfg.cycle_opts = struct('decel', 2);
    cfg.soc0 = 0.85; cfg.T_amb_C = 5; cfg.policy = pols{p}; cfg.seed = 11; cfg.log = true;
    cfg.age = struct('soh', 0.85, 'rscale', 1.3, 'kscale', 0.8);   % aged pack
    cfg.bms_Q = 86 * 0.85; cfg.bms_Rs = 1.3; cfg.bms_rf = 1.3; cfg.bms_kf = 0.8;   % BMS tracks the ageing
    cfg.z0_err = -0.03; cfg.I_off = 0.5; cfg.kA = 1;
    [M, L] = simulate_v2(cfg);
    k = 1:numel(L.t);
    write_csv(fullfile('results', ['X4_' pols{p} '.csv']), {'t', 'v', 'zbar', 'zmaxc', 'zest', 'zp', 'I', 'Ilim', 'Ipl', 'phimin', 'T', 'sig'}, ...
        [L.t(k), L.v(k), L.zbar(k), L.zmaxc(k), L.zest(k), L.zp(k), L.I(k), L.Ilim(k), L.Ipl(k), L.phimin(k), L.T(k), L.sig(k)]);
    fprintf('X4 %-8s regen %.3f kWh, phimin %.1f mV, t_plate %.0f s, Qpl %.2f mAh, t_ceil %.0f s\n', pols{p}, M.E_regen, M.phimin, M.t_plate, M.Qpl, M.t_ceil);
end

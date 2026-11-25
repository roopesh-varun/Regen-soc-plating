function S = mc_sample(Ns, seed)
%MC_SAMPLE  Random operating conditions and BMS errors for the Monte Carlo study.
%   Each row is one vehicle trip: ambient temperature, start SoC, pack age, and what the
%   BMS gets wrong (initial SoC, current-sensor offset, OCV table, capacity, resistance).
rng(seed);
u = @() rand(Ns, 1); g = @(s) s * min(max(randn(Ns, 1), -3), 3);
S.T_amb_C = 5 + 35 * u();                 % 5-40 C
S.soc0 = 0.60 + 0.35 * u();               % 60-95 %
S.soh = 0.80 + 0.20 * u();                % 80-100 % capacity
S.rscale = 1 + 2 * (1 - S.soh);           % resistance grows as capacity fades
S.kscale = 1 - 1.5 * (1 - S.soh);         % kinetics slow down
S.bms_Q = 86 * S.soh .* (1 + g(0.02));    % BMS capacity estimate, 2 % error
S.bms_Rs = S.rscale .* (1 + g(0.05));     % BMS resistance estimate, 5 % error
S.bms_kf = S.kscale .* exp(g(0.05));      % BMS kinetic estimate, 5 % error
S.z0_err = g(0.02);                        % initial SoC error, 2 % sigma
S.I_off = g(0.5);                          % A, current-sensor offset
S.ocv_off = g(0.003);                      % V, OCV-table offset
end

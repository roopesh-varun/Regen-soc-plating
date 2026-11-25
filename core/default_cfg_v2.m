function cfg = default_cfg_v2()
%DEFAULT_CFG_V2  Settings for one vectorised batch of simulate_v2 (Ns samples).
%   Any field may be a scalar (shared) or an Ns x 1 column (one value per sample).
cfg.Ns = 1;                 % independent samples simulated together
cfg.N = 1;                  % cells in series that are simulated (1 = nominal cell, 96 = full pack)
cfg.cycle = 'HARDSTOP'; cfg.cycle_opts = struct('decel', 2);
cfg.dt = 0.2;
cfg.soc0 = 0.90;            % true pack-mean SoC at start
cfg.T_amb_C = 25;           % ambient = coolant = initial temperature (C)
% ---- cell-to-cell variation (used when N > 1) ----
cfg.spread = struct('cap', 0.01, 'R', 0.04, 'kin', 0.08, 'z', 0.01, 'T', 1.5);
cfg.age = struct('soh', 1, 'rscale', 1, 'kscale', 1);
% ---- BMS limit policy ----
cfg.policy = 'SOP';         % SOP | SOPM | ROBUST | ROBUSTA | LEANHIGH | ORACLE
cfg.H = 10;                 % s, prediction horizon of the power limit
cfg.phi_target = 0;         % V, anode-potential floor used by the BMS plating limit
cfg.phi_margin = 0.010;     % SOPM: fixed extra potential margin (industry-style calibration)
cfg.k = 2;                  % ROBUST: margin = k * (EKF sigma + sigma_model)
cfg.sigma_model = 0.01;     % ROBUST: fixed model-bias allowance (as in v1)
cfg.kA = 1;                 % ROBUSTA: SoC margin = kA * (adaptive sigma + sigma_model) + key-on imbalance
cfg.kc = 2.5;               % ROBUSTA: worst cell = kc sigmas of the known spread (max of 96 cells)
cfg.bms_spread = struct('cap', 0.01, 'R', 0.04, 'kin', 0.08, 'z', 0.01, 'T', 1.5);  % what the BMS knows
cfg.lean = 0.02;            % LEANHIGH: estimate deliberately shifted up by this
% ---- SoC estimate ----
cfg.est = 'EKF';            % EKF | BIAS (estimate = true mean SoC + bias) | TRUE
cfg.bias = 0;               % BIAS mode
cfg.sigma_declared = 0.02;  % BIAS mode: the sigma the BMS reports
cfg.z0_err = 0;             % EKF initial SoC error
cfg.I_off = 0;              % A, current-sensor offset
cfg.bms_Rs = 1;             % resistance scale the BMS uses on its tables
cfg.ocv_off = 0;            % V, BMS OCV-table offset
cfg.bms_Q = 86;             % Ah, capacity the BMS believes
cfg.bms_kf = 1; cfg.bms_rf = 1;   % kinetic / resistance factors the BMS believes (SoH tracking)
cfg.ekf_P0 = 0.03; cfg.ekf_Qz = 1e-9; cfg.ekf_Qv = 1e-8; cfg.ekf_Rv = (2e-3)^2;
cfg.ekf_Rv_I = 3e-4;         % V/A: model-error part of the voltage noise, grows with current
cfg.nis_tau = 60;           % s, smoothing of the innovation statistic (ROBUSTA)
% ---- sensors and protection ----
cfg.I_noise = 0.2; cfg.V_noise = 2e-3; cfg.T_noise = 0.5;
cfg.cells_per_sensor = 12;  % one temperature sensor per 12-cell module
cfg.prot_delay = 0.1;
cfg.seed = 1;
cfg.log = false; cfg.log_idx = 1;   % keep time series for these samples
end

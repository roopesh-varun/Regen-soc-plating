function P = cell_params()
%CELL_PARAMS  v2 cell model: reduced physics model (true cell) + BMS circuit model.
%   Built from cell_data.m (published LG M50 parameters, fitted to PyBaMM DFN).
%   Internally every current is on the 5.11 Ah reference cell: I_ref = I_cell / S.
d = cell_data();
P.d = d;
P.F = 96485; P.Rg = 8.314; P.Tref = 298.15;
P.Q = 86;                     % Ah, nominal cell capacity
P.S = d.S;                    % area scale factor
P.x0 = d.x0; P.x100 = d.x100; P.y0 = d.y0; P.y100 = d.y100;
P.ce = d.ce;
P.neg = particle(d.neg, d.A); P.pos = particle(d.pos, d.A);
% graphite OCP on a uniform grid (fast lookup)
xg = linspace(0, 1, 4001)';
P.Un = struct('x0', 0, 'h', xg(2) - xg(1), 'y', interp1(d.Un_tab(:,1), d.Un_tab(:,2), xg, 'linear', 'extrap'));
% lumped terms vs temperature (reference cell), resampled to a 1 K grid for fast lookup
P.Tg = d.Tg_red(:);
Tu = (0:1:40)';
mk = @(y) struct('x0', 0, 'h', 1, 'y', interp1(P.Tg, y(:), Tu));
P.Ro = mk(d.Ro); P.Re = mk(d.Re); P.tau_e = mk(d.tau_e); P.Ra = mk(d.Ra); P.gam = mk(d.gam);
% BMS circuit model
P.ocv = struct('x0', 0, 'h', d.ocv_z(2) - d.ocv_z(1), 'y', d.ocv_V(:));
docv = gradient(d.ocv_V(:), d.ocv_z(2) - d.ocv_z(1));
P.docv = struct('x0', 0, 'h', d.ocv_z(2) - d.ocv_z(1), 'y', docv);
P.ecm_z = d.ecm_z(:); P.ecm_T = d.ecm_T(:);
% resample the circuit-model tables to a uniform grid (SoC 0.30:0.01:0.95, T 0:1:40 C)
zu = (0.30:0.01:0.95)'; [TT, ZZ] = meshgrid(Tu, zu);
g = @(V) struct('z0', 0.30, 'hz', 0.01, 'T0', 0, 'hT', 1, 'V', interp2(P.ecm_T, P.ecm_z, V, TT, ZZ));
P.ecm = struct('R0', g(d.ecm_R0), 'R1', g(d.ecm_R1), 'tau1', g(d.ecm_tau1), 'R2', g(d.ecm_R2), 'tau2', g(d.ecm_tau2));
% limits and thermal
P.Vmax = 4.20; P.Vmin = 2.50;
P.z_ceil = 0.97;              % usable-window ceiling (hidden: needs true SoC)
P.I_hw = 2.5 * P.Q;           % A, hardware/contactor limit
P.m = 1.6; P.cp = 1000; P.hA = 0.8;   % kg, J/kg/K, W/K (lumped, to coolant)
% lithium plating kinetics (O'Kane et al. 2022): k = 1e-9 m/s, alpha_c = 0.65
P.k_pl = 1e-9; P.alpha_pl = 0.65;
end

function e = particle(v, A)
e.R = v(1); e.eps = v(2); e.L = v(3); e.cmax = v(4);
e.Dref = v(5); e.ED = v(6); e.kref = v(7); e.Ek = v(8);
e.Sa = 3 * e.eps / e.R * e.L * A;   % total active surface area, m2
end

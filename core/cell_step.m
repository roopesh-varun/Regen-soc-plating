function [X, V, phi, ocv] = cell_step(X, I, dt, P, C, Tamb)
%CELL_STEP  Advance the TRUE cells one step (reduced single-particle model).
%   I    : cell current (A, + = charge); scalar, column (one per sample) or same size as X
%   C    : per-cell factors: C.capf (capacity/area), C.rf (resistances), C.kf (kinetics)
%   Tamb : coolant/ambient temperature (K), same size as X or scalar
%   Returns terminal voltage V, anode potential at the separator phi (V vs Li/Li+),
%   and the bulk open-circuit voltage ocv. Equations: report Section 4.2.
F = P.F; Rg = P.Rg;
Iref = (I .* ones(size(X.cn))) ./ (P.S * C.capf);     % current on the reference cell
T = X.T;
[Ro, Re, tau, Ra, gam] = lumped_T(P, T);
% --- solid diffusion, three-parameter polynomial approximation (Subramanian 2005)
[X.cn, X.qn, csn] = diffuse(X.cn, X.qn, +Iref, P.neg, T, dt, F, Rg, P.Tref);
[X.cp, X.qp, csp] = diffuse(X.cp, X.qp, -Iref, P.pos, T, dt, F, Rg, P.Tref);
% --- lumped electrolyte polarisation (first order)
a = exp(-dt ./ tau);
X.ve = X.ve .* a + Re .* C.rf .* Iref .* (1 - a);
% --- kinetics (Butler-Volmer, symmetric) and potentials
etan = overpot(P.neg, Iref, csn, T, C.kf, P);
etap = overpot(P.pos, Iref, csp, T, 1, P);
xs = csn / P.neg.cmax; ys = csp / P.pos.cmax;
phin = ulerp(P.Un, xs) - etan;
V = up_ocp(ys) + etap - phin + Iref .* Ro .* C.rf + X.ve;
phi = phin - Iref .* Ra .* C.rf - gam .* X.ve;
% --- bulk OCV, heat and temperature
xa = X.cn / P.neg.cmax; ya = X.cp / P.pos.cmax;
ocv = up_ocp(ya) - ulerp(P.Un, xa);
Iact = I .* ones(size(X.cn));
Qgen = Iact .* (V - ocv);                              % W, irreversible heat
X.T = T + dt * (Qgen - P.hA * (T - Tamb)) / (P.m * P.cp);
% --- plated lithium (Tafel, O'Kane 2022 kinetics, whole anode area: upper bound)
j0pl = F * P.k_pl * P.ce;
ipl = j0pl * (exp(-P.alpha_pl * F * min(phi, 0) ./ (Rg * T)) - 1);   % A/m2, 0 when phi >= 0
X.Qpl = X.Qpl + ipl * P.neg.Sa .* (P.S * C.capf) * dt / 3.6;         % mAh per 86 Ah cell
X.V = V; X.phi = phi;
end

function [c, q, cs] = diffuse(c, q, Iref, e, T, dt, F, Rg, Tref)
J = Iref / (F * e.Sa);                                   % mol/m2/s INTO the particle
D = e.Dref * exp(e.ED / Rg * (1 / Tref - 1 ./ T));
c = c + 3 * J / e.R * dt;
a = 30 * D / e.R^2; b = 45 / (2 * e.R^2) * J;
ea = exp(-a * dt);
q = q .* ea + b ./ a .* (1 - ea);
cs = c + 8 * e.R / 35 * q + e.R ./ (35 * D) .* J;
cs = min(max(cs, 1e-3 * e.cmax), 0.999 * e.cmax);
end

function eta = overpot(e, Iref, cs, T, kf, P)
j0 = e.kref .* kf .* exp(e.Ek / P.Rg * (1 / P.Tref - 1 ./ T)) .* sqrt(P.ce) .* sqrt(cs) .* sqrt(e.cmax - cs);
eta = 2 * P.Rg * T / P.F .* asinh(Iref ./ (2 * e.Sa * j0));
end

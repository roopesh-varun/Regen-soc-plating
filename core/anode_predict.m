function phi = anode_predict(P, xa, qn, ve, I, T, H, capf, kf, rf)
%ANODE_PREDICT  Lowest anode potential (V vs Li/Li+) over the next H seconds if a
%   constant charge current I (A, 86 Ah cell) is applied from the present state.
%   xa : average graphite stoichiometry, qn : diffusion state, ve : electrolyte state
%   capf, kf, rf : capacity, kinetic and resistance factors of the cell being predicted
%   The potential falls monotonically during a constant charge pulse except for the
%   relaxation of ve, so the minimum is at t = 0+ or t = H (both are checked).
e = P.neg; F = P.F; Rg = P.Rg;
Iref = I ./ (P.S * capf);
J = Iref / (F * e.Sa);
D = e.Dref * exp(e.ED / Rg * (1 / P.Tref - 1 ./ T));
[~, Re, tau, Ra, gam] = lumped_T(P, T);
a = 30 * D / e.R^2; b = 45 / (2 * e.R^2) * J;
c0 = xa * e.cmax;
cs0 = c0 + 8 * e.R / 35 * qn + e.R ./ (35 * D) .* J;
ea = exp(-a * H);
qH = qn .* ea + b ./ a .* (1 - ea);
csH = c0 + 3 * J / e.R * H + 8 * e.R / 35 * qH + e.R ./ (35 * D) .* J;
et = exp(-H ./ tau);
veH = ve .* et + Re .* rf .* Iref .* (1 - et);
phi0 = pot(P, e, cs0, Iref, T, kf, rf, Ra, gam, ve);
phiH = pot(P, e, csH, Iref, T, kf, rf, Ra, gam, veH);
phi = min(phi0, phiH);
end

function phi = pot(P, e, cs, Iref, T, kf, rf, Ra, gam, ve)
cs = min(max(cs, 1e-3 * e.cmax), 0.999 * e.cmax);
j0 = e.kref .* kf .* exp(e.Ek / P.Rg * (1 / P.Tref - 1 ./ T)) .* sqrt(P.ce) .* sqrt(cs) .* sqrt(e.cmax - cs);
eta = 2 * P.Rg * T / P.F .* asinh(Iref ./ (2 * e.Sa * j0));
phi = ulerp(P.Un, cs / e.cmax) - eta - Iref .* Ra .* rf - gam .* ve;
end

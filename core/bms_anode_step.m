function B = bms_anode_step(B, Im, Tk, dt, P)
%BMS_ANODE_STEP  The BMS's copy of the anode transient states (diffusion q, electrolyte ve),
%   driven by MEASURED current with nominal parameters. The average stoichiometry is NOT
%   tracked here: the BMS takes it from its SoC estimate, which is where SoC error enters.
e = P.neg;
Iref = Im / P.S;
J = Iref / (P.F * e.Sa);
D = e.Dref * exp(e.ED / P.Rg * (1 / P.Tref - 1 ./ Tk));
a = 30 * D / e.R^2; b = 45 / (2 * e.R^2) * J;
ea = exp(-a * dt);
B.qn = B.qn .* ea + b ./ a .* (1 - ea);
[~, Re, tau] = lumped_T(P, Tk);
et = exp(-dt ./ tau);
B.ve = B.ve .* et + Re .* Iref .* (1 - et);
end

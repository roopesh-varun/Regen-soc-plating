function [Ro, Re, tau, Ra, gam] = lumped_T(P, T)
%LUMPED_T  Reduced-model lumped terms at temperature T (K); linear in T, clamped to 0-40 C.
Tc = T - 273.15;
Ro = ulerp(P.Ro, Tc); Re = ulerp(P.Re, Tc); tau = ulerp(P.tau_e, Tc);
Ra = ulerp(P.Ra, Tc); gam = ulerp(P.gam, Tc);
end

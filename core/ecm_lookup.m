function [R0, R1, t1, R2, t2] = ecm_lookup(P, z, Tc)
%ECM_LOOKUP  BMS 2RC parameters for the 86 Ah cell at SoC z and temperature Tc (C).
%   Tables are for the 5.11 Ah reference cell, so resistances are divided by P.S.
R0 = ulerp2(P.ecm.R0, z, Tc) / P.S;
R1 = ulerp2(P.ecm.R1, z, Tc) / P.S;
t1 = ulerp2(P.ecm.tau1, z, Tc);
R2 = ulerp2(P.ecm.R2, z, Tc) / P.S;
t2 = ulerp2(P.ecm.tau2, z, Tc);
end

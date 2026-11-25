function phi = anode_predict_worst(P, xa, qn, ve, I, T, H, capf, kf, rf, sb, kc)
%ANODE_PREDICT_WORST  Predicted anode potential of a statistically worst cell in the pack.
%   The BMS knows the pack's cell-to-cell spread sb (end-of-line statistics: capacity,
%   resistance, kinetics, temperature). Each spread is applied one at a time (1 sigma) to
%   get its effect on the potential; the effects are combined root-sum-square and the
%   worst cell is kc of those combined sigmas below the nominal cell:
%       phi_worst = phi_nom - kc * sqrt( sum_i (phi_nom - phi_i)^2 )
phi0 = anode_predict(P, xa, qn, ve, I, T, H, capf, kf, rf);
d1 = phi0 - anode_predict(P, xa, qn, ve, I, T, H, capf * (1 - sb.cap), kf, rf);
d2 = phi0 - anode_predict(P, xa, qn, ve, I, T, H, capf, kf, rf * (1 + sb.R));
d3 = phi0 - anode_predict(P, xa, qn, ve, I, T, H, capf, kf * exp(-sb.kin), rf);
d4 = phi0 - anode_predict(P, xa, qn, ve, I, T - sb.T, H, capf, kf, rf);
phi = phi0 - kc * sqrt(d1.^2 + d2.^2 + d3.^2 + d4.^2);
end

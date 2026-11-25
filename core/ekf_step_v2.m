function E = ekf_step_v2(E, Im, Vm, Tc, dt, P, cfg)
%EKF_STEP_V2  One predict/correct step for Ns EKFs on the mean-cell voltage.
%   Im : measured current (A, + charge); Vm : measured mean cell voltage (V); Tc : C
[R0, R1, t1, R2, t2] = ecm_lookup(P, E.z, Tc);
R0 = R0 .* E.Rs; R1 = R1 .* E.Rs; R2 = R2 .* E.Rs;
a1 = exp(-dt ./ t1); a2 = exp(-dt ./ t2);
% ---- predict
E.z = E.z + Im * dt ./ (3600 * E.Q);
E.v1 = a1 .* E.v1 + R1 .* (1 - a1) .* Im;
E.v2 = a2 .* E.v2 + R2 .* (1 - a2) .* Im;
E.P11 = E.P11 + cfg.ekf_Qz;
E.P12 = a1 .* E.P12; E.P13 = a2 .* E.P13;
E.P22 = a1.^2 .* E.P22 + cfg.ekf_Qv; E.P23 = a1 .* a2 .* E.P23; E.P33 = a2.^2 .* E.P33 + cfg.ekf_Qv;
% ---- correct
dU = ulerp(P.docv, E.z);
Vp = ulerp(P.ocv, E.z) + E.ocv_off + E.v1 + E.v2 + R0 .* Im;
e = Vm - Vp;
h1 = E.P11 .* dU + E.P12 + E.P13;
h2 = E.P12 .* dU + E.P22 + E.P23;
h3 = E.P13 .* dU + E.P23 + E.P33;
% measurement noise grows with current: the circuit model is least accurate at high current
Rv = cfg.ekf_Rv + (cfg.ekf_Rv_I * Im).^2;
S = dU .* h1 + h2 + h3 + Rv;
k1 = h1 ./ S; k2 = h2 ./ S; k3 = h3 ./ S;
E.z = E.z + k1 .* e; E.v1 = E.v1 + k2 .* e; E.v2 = E.v2 + k3 .* e;
E.P11 = E.P11 - k1 .* k1 .* S; E.P12 = E.P12 - k1 .* k2 .* S; E.P13 = E.P13 - k1 .* k3 .* S;
E.P22 = E.P22 - k2 .* k2 .* S; E.P23 = E.P23 - k2 .* k3 .* S; E.P33 = E.P33 - k3 .* k3 .* S;
E.P11 = max(E.P11, 1e-10);
E.z = min(max(E.z, 0), 1);
w = min(dt / cfg.nis_tau, 1);
E.nis = E.nis + w * (e.^2 ./ S - E.nis);
E.sig = sqrt(E.P11);
end

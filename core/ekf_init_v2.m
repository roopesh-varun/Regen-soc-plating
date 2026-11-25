function E = ekf_init_v2(z0, Q, Rs, ocv_off, P0, Ns)
%EKF_INIT_V2  Vectorised 3-state EKF (SoC, two RC voltages) for Ns independent BMSs.
%   z0 : initial SoC estimate (Ns x 1); Q : capacity the BMS believes (Ah)
%   Rs : resistance scale the BMS uses (x its tables); ocv_off : OCV-table offset (V)
o = ones(Ns, 1);
E.z = z0 .* o; E.v1 = 0 * o; E.v2 = 0 * o;
E.P11 = P0^2 * o; E.P12 = 0 * o; E.P13 = 0 * o; E.P22 = 1e-6 * o; E.P23 = 0 * o; E.P33 = 1e-6 * o;
E.Q = Q .* o; E.Rs = Rs .* o; E.ocv_off = ocv_off .* o;
E.nis = o;          % smoothed normalised innovation squared (1 = consistent)
E.sig = sqrt(E.P11);
end

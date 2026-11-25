function Ilim = plating_limit_worst(P, xa, qn, ve, T, H, target, Imax, capf, kf, rf, sb, kc)
%PLATING_LIMIT_WORST  Largest constant charge current keeping the predicted potential of
%   the statistically worst cell (anode_predict_worst) >= target over H seconds.
Imax = Imax .* ones(size(xa));
lo = zeros(size(xa)); hi = Imax;
f = @(I) anode_predict_worst(P, xa, qn, ve, I, T, H, capf, kf, rf, sb, kc) >= target;
ok_hi = f(hi); ok_lo = f(lo);
for it = 1:14
    mid = 0.5 * (lo + hi); ok = f(mid);
    lo(ok) = mid(ok); hi(~ok) = mid(~ok);
end
Ilim = lo; Ilim(ok_hi) = Imax(ok_hi); Ilim(~ok_lo) = 0;
end

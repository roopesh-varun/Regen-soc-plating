function Ilim = plating_limit_v2(P, xa, qn, ve, T, H, target, Imax, capf, kf, rf)
%PLATING_LIMIT_V2  Largest constant charge current (A, 86 Ah cell) that keeps the
%   predicted anode potential >= target (V) over the next H seconds. Bisection, vectorised.
Imax = Imax .* ones(size(xa));
lo = zeros(size(xa)); hi = Imax;
ok_hi = anode_predict(P, xa, qn, ve, hi, T, H, capf, kf, rf) >= target;
ok_lo = anode_predict(P, xa, qn, ve, lo, T, H, capf, kf, rf) >= target;
for it = 1:14
    mid = 0.5 * (lo + hi);
    ok = anode_predict(P, xa, qn, ve, mid, T, H, capf, kf, rf) >= target;
    lo(ok) = mid(ok); hi(~ok) = mid(~ok);
end
Ilim = lo;
Ilim(ok_hi) = Imax(ok_hi);
Ilim(~ok_lo) = 0;
end

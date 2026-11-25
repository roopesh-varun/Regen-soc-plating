function y = ulerp(tab, x)
%ULERP  Fast clamped linear interpolation on a UNIFORM grid (any array size of x).
%   tab.x0 (first grid point), tab.h (spacing), tab.y (values)
n = numel(tab.y); yv = tab.y(:);
u = (x(:) - tab.x0) / tab.h;
u = min(max(u, 0), n - 1 - 1e-9);
i = floor(u);
w = u - i;
y = reshape(yv(i + 1) .* (1 - w) + yv(i + 2) .* w, size(x));
end

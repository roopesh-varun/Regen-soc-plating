function y = ulerp2(tab, z, Tc)
%ULERP2  Fast clamped bilinear interpolation on a uniform (SoC, T) grid.
[nz, nT] = size(tab.V);
u = min(max((z - tab.z0) / tab.hz, 0), nz - 1 - 1e-9);
w = min(max((Tc - tab.T0) / tab.hT, 0), nT - 1 - 1e-9);
i = floor(u); j = floor(w); fu = u - i; fw = w - j;
id = i + 1 + j * nz;
V = tab.V;
y = (V(id) .* (1 - fu) + V(id + 1) .* fu) .* (1 - fw) + (V(id + nz) .* (1 - fu) + V(id + nz + 1) .* fu) .* fw;
y = reshape(y, size(z));
end

function [C, dz, dT] = pack_sample(Ns, N, sp, age)
%PACK_SAMPLE  Cell-to-cell variation for Ns packs of N series cells.
%   sp.cap, sp.R, sp.kin : 1-sigma relative spread of capacity, resistance, kinetics
%   sp.z : 1-sigma SoC imbalance (fraction);  sp.T : 1-sigma temperature offset (K)
%   age.soh, age.rscale, age.kscale : pack-level ageing multipliers (Ns x 1)
%   Spreads are truncated at +/-3 sigma. N = 1 gives a nominal single cell.
tr = @(x) min(max(x, -3), 3);
o = ones(Ns, N);
if N == 1
    C.capf = o; C.rf = o; C.kf = o; dz = 0 * o; dT = 0 * o;
else
    C.capf = 1 + sp.cap * tr(randn(Ns, N));
    C.rf = 1 + sp.R * tr(randn(Ns, N));
    C.kf = exp(sp.kin * tr(randn(Ns, N)));
    dz = sp.z * tr(randn(Ns, N)); dz = dz - mean(dz, 2);       % imbalance about the pack mean
    dT = sp.T * tr(randn(Ns, N));
end
C.capf = C.capf .* age.soh; C.rf = C.rf .* age.rscale; C.kf = C.kf .* age.kscale;
end

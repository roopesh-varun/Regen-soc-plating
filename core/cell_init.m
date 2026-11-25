function X = cell_init(P, z0, T0, C)
%CELL_INIT  True-cell states for an array of cells (any size), all at rest.
%   z0 : true SoC (fraction); T0 : temperature (K); C : per-cell factors (capf)
X.cn = (P.x0 + z0 .* (P.x100 - P.x0)) * P.neg.cmax;
X.cp = (P.y0 + z0 .* (P.y100 - P.y0)) * P.pos.cmax;
X.qn = zeros(size(z0)); X.qp = zeros(size(z0)); X.ve = zeros(size(z0));
X.T = T0 .* ones(size(z0));
X.Qpl = zeros(size(z0));            % mAh plated (upper-bound estimate), per 86 Ah cell
X.phi = 0.1 * ones(size(z0)); X.V = zeros(size(z0));
end

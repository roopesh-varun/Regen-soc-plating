function [names, A] = metrics_row(M)
%METRICS_ROW  Metrics struct of simulate_v2 -> matrix (one row per sample).
names = {'E_avail', 'E_regen', 'E_fric', 'E_brake', 'E_drive', 't_ceil', 'zmax', 'phimin', ...
         't_plate', 'Qpl', 'err_mean', 'err_max', 'err_min', 't_clip', 'breach_pl', 'breach_ceil'};
A = zeros(numel(M.E_regen), numel(names));
for i = 1:numel(names), A(:, i) = double(M.(names{i})(:)); end
end

root = fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root, 'core')); cd(root);
c = {'HARDSTOP', 'MIDC', 'HILL'}; o = {struct('decel', 2), struct(), struct()}; R = zeros(3, 2);
for i = 1:3, [t, v] = drive_cycle(c{i}, 0.2, o{i}); R(i, :) = [i, trapz(t, v) / 1000]; end
write_csv(fullfile('results', 'cycle_km.csv'), {'cycle', 'km'}, R); disp(R)

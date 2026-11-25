%EXP_X0_MAPS  Static maps: graphite OCP and the 10 s plating-limit current from rest vs SoC and T.
root = fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root, 'core')); cd(root);
P = cell_params();
z = (0.30:0.005:0.97)'; xa = P.x0 + z * (P.x100 - P.x0);
R = [z, xa, ulerp(P.Un, xa), ulerp(P.ocv, z)];
for T = [0 10 25 40]
    R = [R, plating_limit_v2(P, xa, 0 * z, 0 * z, T + 273.15 + 0 * z, 10, 0, P.I_hw, 1, 1, 1)]; %#ok<AGROW>
end
write_csv(fullfile('results', 'X0_maps.csv'), {'soc', 'x_graphite', 'U_n', 'ocv', 'Ipl_0C', 'Ipl_10C', 'Ipl_25C', 'Ipl_40C'}, R);

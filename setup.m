%SETUP  Add the project folders to the MATLAB path. Run once per MATLAB session.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'core'));
addpath(fullfile(root, 'scripts'));
addpath(fullfile(root, 'scripts', 'matlab_runs'));
fprintf('ED5361 regen project: paths added. Try:  [M, L] = simulate_v2(default_cfg_v2());\n');

% Check the MATLAB reduced cell model reproduces the Python one (used for fitting).
root = fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root, 'core'));
P = cell_params();
for tag = {'val_HARDSTOP_E3_T10_S92', 'val_hill95_bias+0_T25_S90'}
  r = csvread(fullfile(root, 'pyref', 'dfn_data', [tag{1} '_reduced.csv']), 1, 0);
  T = sscanf(regexp(tag{1}, '_T(\d+)_', 'tokens', 'once'){1}, '%d'); z0 = sscanf(regexp(tag{1}, '_S(\d+)', 'tokens', 'once'){1}, '%d') / 100;
  C.capf = 1; C.rf = 1; C.kf = 1;
  X = cell_init(P, z0, T + 273.15, C); X.T = T + 273.15;
  n = size(r, 1); V = zeros(n, 1); ph = V;
  for k = 1:n
    dt = 0; if k > 1, dt = r(k,1) - r(k-1,1); end
    I86 = r(k,2) * P.S;
    Tk = X.T; [X, V(k), ph(k)] = cell_step(X, I86, dt, P, C, Tk); X.T = Tk;  % isothermal like the DFN runs
  end
  fprintf('%s: max |V_mat - V_py| = %.3g mV, max |phi_mat - phi_py| = %.3g mV, rmse phi vs DFN = %.2f mV\n', ...
      tag{1}, 1e3*max(abs(V - r(:,4))), 1e3*max(abs(ph - r(:,6))), 1e3*sqrt(mean((ph - r(:,5)).^2)));
end

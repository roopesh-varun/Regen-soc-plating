%EXP_VEHICLE_STATS  Vehicle-side numbers for each driving pattern (no battery involved):
%   distance, braking energy at the wheel, regen energy the motor could deliver to the DC bus,
%   peak powers; plus time series for plotting.
root = fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root, 'core')); cd(root);
veh = params_vehicle_v2(); dt = 0.2;
cyc = {'HARDSTOP', 'HARDSTOP', 'HARDSTOP', 'MIDC', 'HILL'}; opt = {struct('decel', 1), struct('decel', 2), struct('decel', 3), struct(), struct()};
R = zeros(5, 9);
for c = 1:5
    [t, v, g] = drive_cycle(cyc{c}, dt, opt{c}); K = numel(t);
    a = [diff(v) / dt; 0]; vm = [(v(1:end-1) + v(2:end)) / 2; v(end)];
    Pw = zeros(K, 1); Pa = Pw; Pb = Pw;
    for k = 1:K, [Pw(k), Pa(k), Pb(k)] = vehicle_step(vm(k), a(k), g(k), veh); end
    Etr = sum(max(Pw, 0)) * dt / 3.6e6 / (veh.eta_gear * veh.eta_mot) + veh.P_aux * t(end) / 3.6e6;
    R(c, :) = [c, trapz(t, v) / 1000, t(end), sum(Pb) * dt / 3.6e6, sum(Pa) * dt / 3.6e6, max(Pb) / 1e3, max(Pa) / 1e3, Etr, sum(Pb > 0) * dt];
    if any(c == [2 4 5])
        write_csv(fullfile('results', sprintf('VEH_ts_%d.csv', c)), {'t', 'v_kmh', 'grade', 'P_wheel_kW', 'P_brake_kW', 'P_avail_kW'}, [t, v * 3.6, g, Pw / 1e3, Pb / 1e3, Pa / 1e3]);
    end
end
write_csv(fullfile('results', 'VEH_stats.csv'), {'cycle', 'km', 'dur_s', 'E_brake_kWh', 'E_avail_kWh', 'Pbrake_max_kW', 'Pavail_max_kW', 'E_traction_dc_kWh', 't_brake_s'}, R);
disp(R)

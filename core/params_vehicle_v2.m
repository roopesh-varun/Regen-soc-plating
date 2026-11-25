function veh = params_vehicle_v2()
%PARAMS_VEHICLE_V2  Compact Indian-market EV, 96s1p pack of 86 Ah cells (~30 kWh).
veh.m = 1650; veh.rot = 0.05; veh.CdA = 0.33 * 2.4; veh.Crr = 0.010;
veh.rho = 1.20; veh.g = 9.81; veh.eta_gear = 0.97; veh.eta_mot = 0.92;
veh.P_mot_max = 100e3; veh.P_regen_max = 60e3;
veh.v_fade_lo = 5 / 3.6; veh.v_fade_hi = 15 / 3.6; veh.P_aux = 400;
veh.ns = 96;
end

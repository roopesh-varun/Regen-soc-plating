function [P_wheel, P_avail_dc, P_brake] = vehicle_step(v, a, grade, veh)
%VEHICLE_STEP  Backward-facing road load.
%   P_wheel    : wheel power demand (W), > 0 traction, < 0 braking
%   P_avail_dc : regen power the e-machine can deliver to the DC bus (W, >= 0)
%   P_brake    : total braking power needed at the wheel (W, >= 0)
th = atan(grade);
F = veh.m * (1 + veh.rot) * a ...
  + 0.5 * veh.rho * veh.CdA * v^2 ...
  + veh.m * veh.g * veh.Crr * cos(th) * (v > 0.01) ...
  + veh.m * veh.g * sin(th);
P_wheel = F * v;
P_brake = max(-P_wheel, 0);
fade = min(max((v - veh.v_fade_lo) / (veh.v_fade_hi - veh.v_fade_lo), 0), 1);
P_mech = min(P_brake * veh.eta_gear * fade, veh.P_regen_max);
P_avail_dc = P_mech * veh.eta_mot;
end

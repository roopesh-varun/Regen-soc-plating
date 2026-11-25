% Adds the model folder to the path (works from any folder)
addpath(fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'core'));

clc;
clear;
close all;

%% 1. Load configuration
cfg = default_cfg_v2();

%% 2. Enable data logging
cfg.log = true;
cfg.log_idx = 1;

%% 3. Run simulation
[M, L] = simulate_v2(cfg);

disp('Simulation completed successfully!');
disp(M);

%% 4. Plot simulation results

figure('Name','Battery Simulation Results', ...
       'Color','w','Position',[100 100 1200 750]);

% Plot 1: True SOC and estimated SOC
subplot(3,2,1);
plot(L.t,L.zbar(:,1)*100,'b','LineWidth',1.5);
hold on;
plot(L.t,L.zest(:,1)*100,'r--','LineWidth',1.5);
plot(L.t,L.zmaxc(:,1)*100,'k:','LineWidth',1.2);
xlabel('Time (s)');
ylabel('SOC (%)');
title('SOC Estimation');
legend('True SOC','Estimated SOC','Maximum Cell SOC');
grid on;

% Plot 2: Battery current
subplot(3,2,2);
plot(L.t,L.I(:,1),'LineWidth',1.5);
xlabel('Time (s)');
ylabel('Current (A)');
title('Battery Current');
grid on;

% Plot 3: Battery power
subplot(3,2,3);
plot(L.t,L.P_bat(:,1)/1000,'b','LineWidth',1.5);
hold on;
plot(L.t,L.P_avail/1000,'r--','LineWidth',1.5);
xlabel('Time (s)');
ylabel('Power (kW)');
title('Battery and Regenerative Power');
legend('Battery Power','Available Regen Power');
grid on;

% Plot 4: Anode potential
subplot(3,2,4);
plot(L.t,L.phimin(:,1)*1000,'LineWidth',1.5);
hold on;
yline(cfg.phi_target*1000,'r--','Plating threshold');
xlabel('Time (s)');
ylabel('Potential (mV)');
title('Minimum Anode Potential');
legend('Anode Potential','Target');
grid on;

% Plot 5: Battery temperature
subplot(3,2,5);
plot(L.t,L.T(:,1),'LineWidth',1.5);
xlabel('Time (s)');
ylabel('Temperature (°C)');
title('Battery Temperature');
grid on;

% Plot 6: Charging current limits
subplot(3,2,6);
plot(L.t,L.Ilim(:,1),'b','LineWidth',1.5);
hold on;
plot(L.t,L.Ipl(:,1),'r--','LineWidth',1.5);
xlabel('Time (s)');
ylabel('Current (A)');
title('BMS Charging Current Limits');
legend('Overall Current Limit','Plating Current Limit');
grid on;

sgtitle('EV Battery and BMS Simulation Results');

%% 5. Save graphs
saveas(gcf,'Battery_Simulation_Plots.png');

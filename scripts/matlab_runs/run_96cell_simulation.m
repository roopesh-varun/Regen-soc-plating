% Adds the model folder to the path (works from any folder)
addpath(fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'core'));

clc;
clear;
close all;

%% 1. Load default configuration
cfg = default_cfg_v2();

%% 2. Configure 96-cell battery pack
cfg.Ns = 1;
cfg.N = 96;

%% 3. Simulation conditions
cfg.cycle = 'HARDSTOP';
cfg.soc0 = 0.90;
cfg.T_amb_C = 25;
cfg.policy = 'SOP';
cfg.est = 'EKF';

%% 4. Enable cell variation
cfg.spread.cap = 0.01;
cfg.spread.R = 0.04;
cfg.spread.kin = 0.08;
cfg.spread.z = 0.01;
cfg.spread.T = 1.5;

%% 5. Enable logging
cfg.log = true;
cfg.log_idx = 1;
cfg.seed = 1;

%% 6. Run simulation
[M,L] = simulate_v2(cfg);

%% 7. Display results
disp('96-CELL PACK SIMULATION RESULTS');
disp(M);

%% 8. Plot results
figure('Name','96 Cell Battery Pack Results', ...
       'Color','w','Position',[100 100 1250 800]);

% Plot 1: SOC
subplot(3,2,1);
plot(L.t,L.zbar(:,1)*100,'b','LineWidth',1.5);
hold on;
plot(L.t,L.zmaxc(:,1)*100,'k--','LineWidth',1.3);
plot(L.t,L.zest(:,1)*100,'r','LineWidth',1.5);
xlabel('Time (s)');
ylabel('SOC (%)');
title('96-Cell Pack SOC Estimation');
legend('Mean True SOC','Maximum Cell SOC','EKF Estimated SOC');
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
plot(L.t,L.phimin(:,1)*1000,'b','LineWidth',1.5);
hold on;
yline(cfg.phi_target*1000,'r--','Plating threshold');
xlabel('Time (s)');
ylabel('Potential (mV)');
title('Minimum Anode Potential');
legend('Minimum Potential','Plating Threshold');
grid on;

% Plot 5: Temperature
subplot(3,2,5);
plot(L.t,L.T(:,1),'LineWidth',1.5);
xlabel('Time (s)');
ylabel('Temperature (C)');
title('Mean Battery Temperature');
grid on;

% Plot 6: Charging current limits
subplot(3,2,6);
plot(L.t,L.Ilim(:,1),'b','LineWidth',1.5);
hold on;
plot(L.t,L.Ipl(:,1),'r--','LineWidth',1.5);
xlabel('Time (s)');
ylabel('Current (A)');
title('BMS Charging Current Limits');
legend('Overall Limit','Plating Limit');
grid on;

sgtitle('96-Cell Battery Pack Simulation');

%% 9. Save results
saveas(gcf,'96Cell_Battery_Results.png');
save('96Cell_Battery_Data.mat','M','L','cfg');

disp('96-cell simulation and plotting completed.');

% Adds the model folder to the path (works from any folder)
addpath(fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'core'));

clc;
clear;
close all;

%% TEMPERATURE SENSITIVITY STUDY

temperatures = [0 10 25 40];
n = length(temperatures);

Eregen = zeros(n,1);
Efric = zeros(n,1);
Phimin = zeros(n,1);
Tplate = zeros(n,1);
Qpl = zeros(n,1);
Tfinal = zeros(n,1);
SOC_RMSE = zeros(n,1);
MaxSOC = zeros(n,1);

%% Run simulations

for i = 1:n

    cfg = default_cfg_v2();

    % Battery pack
    cfg.Ns = 1;
    cfg.N = 96;

    % Common conditions
    cfg.cycle = 'HARDSTOP';
    cfg.policy = 'SOP';
    cfg.est = 'EKF';

    cfg.soc0 = 0.90;
    cfg.T_amb_C = temperatures(i);

    % Same random seed
    cfg.seed = 1;

    % Enable logging
    cfg.log = true;
    cfg.log_idx = 1;

    % Run model
    [M,L] = simulate_v2(cfg);

    % Energy and safety metrics
    Eregen(i) = M.E_regen;
    Efric(i) = M.E_fric;
    Phimin(i) = M.phimin;
    Tplate(i) = M.t_plate;
    Qpl(i) = M.Qpl;
    Tfinal(i) = L.T(end,1);
    MaxSOC(i) = M.zmax*100;

    % SOC estimation accuracy
    err = (L.zest(:,1)-L.zbar(:,1))*100;
    SOC_RMSE(i) = sqrt(mean(err.^2));

    fprintf('Completed temperature: %d C\n',...
        temperatures(i));

end

%% Results table

Temperature_Results = table(temperatures',...
    Eregen,Efric,Phimin,Tplate,Qpl,...
    SOC_RMSE,MaxSOC,Tfinal,...
    'VariableNames',{'Ambient_C','Regen_kWh',...
    'Friction_kWh','MinAnode_mV','PlatingTime_s',...
    'PlatedLithium','SOC_RMSE','MaxSOC_percent',...
    'FinalTemp_C'});

disp('TEMPERATURE SENSITIVITY RESULTS');
disp(Temperature_Results);

%% Plot 1: Minimum anode potential

figure('Color','w');

plot(temperatures,Phimin,'o-','LineWidth',1.8);

xlabel('Ambient Temperature (C)');
ylabel('Minimum Anode Potential (mV)');
title('Temperature vs Anode Potential');
grid on;

%% Plot 2: Regenerative energy

figure('Color','w');

plot(temperatures,Eregen,'o-','LineWidth',1.8);

xlabel('Ambient Temperature (C)');
ylabel('Regenerative Energy (kWh)');
title('Temperature vs Regenerative Energy');
grid on;

%% Plot 3: SOC RMSE

figure('Color','w');

plot(temperatures,SOC_RMSE,'o-','LineWidth',1.8);

xlabel('Ambient Temperature (C)');
ylabel('SOC RMSE (percentage points)');
title('Temperature vs SOC Estimation Accuracy');
grid on;

%% Plot 4: Friction braking energy

figure('Color','w');

plot(temperatures,Efric,'o-','LineWidth',1.8);

xlabel('Ambient Temperature (C)');
ylabel('Friction Energy (kWh)');
title('Temperature vs Friction Braking Energy');
grid on;

%% Save results

save('Temperature_Study.mat','Temperature_Results');

writetable(Temperature_Results,...
    'Temperature_Study.csv');

disp('TEMPERATURE STUDY COMPLETED');

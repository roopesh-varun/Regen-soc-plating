% Adds the model folder to the path (works from any folder)
addpath(fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'core'));

clc;
clear;
close all;

%% BMS POLICY COMPARISON WITH SOC ACCURACY

policies = {'SOP','SOPM','ROBUST','ROBUSTA','ORACLE'};

n = numel(policies);

%% Initialize result variables

Eregen = zeros(n,1);
Efric = zeros(n,1);
Phimin = zeros(n,1);
Tplate = zeros(n,1);
Qpl = zeros(n,1);
MaxSOC = zeros(n,1);

RMSE = zeros(n,1);
MAE = zeros(n,1);
MaxAbsError = zeros(n,1);
Bias = zeros(n,1);

%% Run all five BMS policies

for i = 1:n

    cfg = default_cfg_v2();

    % 96-cell battery pack
    cfg.Ns = 1;
    cfg.N = 96;

    % Common simulation conditions
    cfg.cycle = 'HARDSTOP';
    cfg.soc0 = 0.90;
    cfg.T_amb_C = 25;
    cfg.est = 'EKF';

    % Select BMS policy
    cfg.policy = policies{i};

    % Same random seed for fair comparison
    cfg.seed = 1;

    % Enable logging for SOC accuracy
    cfg.log = true;
    cfg.log_idx = 1;

    % Run simulation
    [M,L] = simulate_v2(cfg);

    % Store energy and safety results
    Eregen(i) = M.E_regen;
    Efric(i) = M.E_fric;
    Phimin(i) = M.phimin;
    Tplate(i) = M.t_plate;
    Qpl(i) = M.Qpl;
    MaxSOC(i) = M.zmax * 100;

    % Calculate SOC estimation error
    err = (L.zest(:,1) - L.zbar(:,1))*100;

    % SOC accuracy metrics
    RMSE_value = sqrt(mean(err.^2));
    MAE_value = mean(abs(err));
    MaxAbs_value = max(abs(err));
    Bias_value = mean(err);

    % Store accuracy metrics
    RMSE(i) = RMSE_value;
    MAE(i) = MAE_value;
    MaxAbsError(i) = MaxAbs_value;
    Bias(i) = Bias_value;

    fprintf('Completed policy: %s\n',policies{i});

end

%% Display comparison table

Results = table(policies',Eregen,Efric,Phimin,...
    Tplate,Qpl,RMSE,MAE,MaxAbsError,Bias,MaxSOC,...
    'VariableNames',{'Policy','Eregen_kWh',...
    'Efric_kWh','MinAnode_mV','PlatingTime_s',...
    'PlatedLithium','RMSE','MAE',...
    'MaxAbsError','Bias','MaxSOC_percent'});

disp('==========================================');
disp('       BMS POLICY COMPARISON RESULTS');
disp('==========================================');

disp(Results);

%% Plot 1: Regenerative energy

figure('Color','w');

bar(Eregen);

set(gca,'XTick',1:n,'XTickLabel',policies);

xlabel('BMS Policy');
ylabel('Energy (kWh)');
title('Regenerative Energy Comparison');

grid on;

%% Plot 2: Minimum anode potential

figure('Color','w');

bar(Phimin);

set(gca,'XTick',1:n,'XTickLabel',policies);

xlabel('BMS Policy');
ylabel('Minimum Anode Potential (mV)');
title('Lithium Plating Safety Comparison');

grid on;

%% Plot 3: SOC RMSE

figure('Color','w');

bar(RMSE);

set(gca,'XTick',1:n,'XTickLabel',policies);

xlabel('BMS Policy');
ylabel('RMSE (percentage points)');
title('SOC Estimation RMSE Comparison');

grid on;

%% Plot 4: SOC MAE

figure('Color','w');

bar(MAE);

set(gca,'XTick',1:n,'XTickLabel',policies);

xlabel('BMS Policy');
ylabel('MAE (percentage points)');
title('SOC Estimation MAE Comparison');

grid on;

%% Plot 5: Maximum absolute SOC error

figure('Color','w');

bar(MaxAbsError);

set(gca,'XTick',1:n,'XTickLabel',policies);

xlabel('BMS Policy');
ylabel('Maximum Absolute Error (percentage points)');
title('Maximum SOC Estimation Error');

grid on;

%% Save results

save('BMS_Policy_Comparison.mat','Results');

writetable(Results,'BMS_Policy_Comparison.csv');

disp('==========================================');
disp('BMS POLICY COMPARISON COMPLETED');
disp('Results saved successfully.');
disp('==========================================');

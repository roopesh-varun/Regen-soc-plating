% Adds the model folder to the path (works from any folder)
addpath(fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'core'));

clc;
clear;
close all;

%% COLD TEMPERATURE BMS POLICY COMPARISON

temperatures = [0 10];
policies = {'SOP','SOPM','ROBUST','ROBUSTA','ORACLE'};

nt = length(temperatures);
np = length(policies);
nr = nt*np;

% Result storage
Temp = zeros(nr,1);
Policy = cell(nr,1);

Eregen = zeros(nr,1);
Efric = zeros(nr,1);
Phimin = zeros(nr,1);
Tplate = zeros(nr,1);
Qpl = zeros(nr,1);
RMSE = zeros(nr,1);
MAE = zeros(nr,1);
MaxError = zeros(nr,1);

r = 0;

%% Run all combinations

for t = 1:nt

    for p = 1:np

        r = r + 1;

        cfg = default_cfg_v2();

        % Battery pack
        cfg.Ns = 1;
        cfg.N = 96;

        % Operating conditions
        cfg.cycle = 'HARDSTOP';
        cfg.soc0 = 0.90;
        cfg.T_amb_C = temperatures(t);

        % BMS configuration
        cfg.policy = policies{p};
        cfg.est = 'EKF';

        % Repeatable conditions
        cfg.seed = 1;

        % Enable logging
        cfg.log = true;
        cfg.log_idx = 1;

        % Run simulation
        [M,L] = simulate_v2(cfg);

        % Save conditions
        Temp(r) = temperatures(t);
        Policy{r} = policies{p};

        % Energy metrics
        Eregen(r) = M.E_regen;
        Efric(r) = M.E_fric;

        % Plating metrics
        Phimin(r) = M.phimin;
        Tplate(r) = M.t_plate;
        Qpl(r) = M.Qpl;

        % SOC accuracy
        err = (L.zest(:,1)-L.zbar(:,1))*100;

        RMSE(r) = sqrt(mean(err.^2));
        MAE(r) = mean(abs(err));
        MaxError(r) = max(abs(err));

        fprintf('Temperature: %d C | Policy: %s completed\n',...
            temperatures(t),policies{p});

    end
end

%% Results table

Results = table(Temp,Policy,Eregen,Efric,...
    Phimin,Tplate,Qpl,RMSE,MAE,MaxError,...
    'VariableNames',{'Temperature_C','Policy',...
    'Regen_kWh','Friction_kWh','MinAnode_mV',...
    'PlatingTime_s','PlatedLithium_mAh',...
    'SOC_RMSE','SOC_MAE','SOC_MaxError'});

disp('COLD TEMPERATURE POLICY COMPARISON');
disp(Results);

%% Plot 1: Anode potential comparison

figure('Color','w');

for t = 1:nt

    subplot(1,2,t);

    idx = Temp == temperatures(t);

    bar(Phimin(idx));

    set(gca,'XTick',1:np,'XTickLabel',policies);

    yline(0,'r--','Plating threshold');

    xlabel('BMS Policy');
    ylabel('Minimum Anode Potential (mV)');

    title(sprintf('Anode Potential at %d C',temperatures(t)));

    grid on;

end

%% Plot 2: Regenerative energy

figure('Color','w');

for t = 1:nt

    subplot(1,2,t);

    idx = Temp == temperatures(t);

    bar(Eregen(idx));

    set(gca,'XTick',1:np,'XTickLabel',policies);

    xlabel('BMS Policy');
    ylabel('Regenerative Energy (kWh)');

    title(sprintf('Energy Recovery at %d C',temperatures(t)));

    grid on;

end

%% Plot 3: Plating accumulation

figure('Color','w');

for t = 1:nt

    subplot(1,2,t);

    idx = Temp == temperatures(t);

    bar(Qpl(idx));

    set(gca,'XTick',1:np,'XTickLabel',policies);

    xlabel('BMS Policy');
    ylabel('Plated Lithium (mAh)');

    title(sprintf('Plating at %d C',temperatures(t)));

    grid on;

end

%% Save results

save('Cold_Temperature_Comparison.mat','Results');

writetable(Results,'Cold_Temperature_Comparison.csv');

disp('COLD TEMPERATURE POLICY COMPARISON COMPLETED');

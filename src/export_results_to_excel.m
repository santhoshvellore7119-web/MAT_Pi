% EXPORT_RESULTS_TO_EXCEL
% Pure MATLAB script to export the trained 4-Step LSTM & TD3-RL model weights,
% normalization statistics, and Simulink closed-loop benchmark trajectories
% into a multi-sheet Excel (.xlsx) workbook for faculty review.
%
% Author: Santhosh.G (25BEL0016)

clc; clear; close all;

fprintf('====================================================================\n');
fprintf('EXPORTING TRAINED MODELS & SIMULINK RESULTS TO EXCEL (.XLSX)\n');
fprintf('====================================================================\n\n');

srcDir = fileparts(mfilename('fullpath'));
if isempty(srcDir), srcDir = pwd; end
projRoot = fileparts(srcDir);
addpath(genpath(projRoot));

outFile = fullfile(projRoot, 'results', 'MAT_Pi_Trained_Model_and_Simulink_Results.xlsx');
if isfile(outFile), delete(outFile); end

%% 1. Load Trained Models & Benchmark Artifacts
fprintf('[1/4] Loading trained models and Simulink benchmark results...\n');
s_micro = load(fullfile(projRoot, 'results', 'microgrid_benchmark_results.mat'));
s_bench = load(fullfile(projRoot, 'results', 'benchmark_results.mat'));
s_fw    = load(fullfile(projRoot, 'trained_models', 'lstm_forward_weights.mat'));

mg = s_micro.microgridData;
bm = s_bench.benchmarkData;
np = s_fw.normParams;

%% 2. Sheet 1: Summary_Metrics
fprintf('[2/4] Writing Sheet 1: Summary_Metrics...\n');
m_mg = mg.metrics;
m_bm = bm.metrics;

summaryCells = {
    'PROJECT & AUTHOR METADATA', '', '', '', '';
    'Author / Student Name', 'Santhosh.G', 'Register Number', '25BEL0016', '';
    'GitHub Repository', 'https://github.com/santhoshvellore7119-web/MAT_Pi', 'Platform', 'MATLAB R2025b & Simulink', '';
    '', '', '', '', '';
    'TABLE 1: 300V SOLAR PV + BATTERY STORAGE (BESS) DC MICROGRID SIMULINK BENCHMARK METRICS', '', '', '', '';
    'Performance Metric', 'Conventional Discrete PI', 'TD3-RL Agent (Trained)', 'Trained 4-Step Memory LSTM', 'Best Controller';
    'Integral Absolute Error - IAE (V*s)', m_mg(1).IAE, m_mg(2).IAE, m_mg(3).IAE, 'TD3-RL (-26.45% vs PI)';
    'Integral Time Absolute Error - ITAE (V*s^2)', m_mg(1).ITAE, m_mg(2).ITAE, m_mg(3).ITAE, 'TD3-RL (-31.62% vs PI)';
    'Root Mean Square Error - RMSE (V)', m_mg(1).RMSE, m_mg(2).RMSE, m_mg(3).RMSE, 'TD3-RL Agent';
    'Peak Startup Overshoot (%)', m_mg(1).PeakOvershoot, m_mg(2).PeakOvershoot, m_mg(3).PeakOvershoot, 'Trained 4-Step LSTM (0.42%)';
    'Solar Cloud Voltage Droop at t=8s (V)', m_mg(1).Droop_Cloud, m_mg(2).Droop_Cloud, m_mg(3).Droop_Cloud, 'TD3-RL Agent (1.80 V)';
    'Heavy Load Voltage Droop at t=16s (V)', m_mg(1).Droop_Load, m_mg(2).Droop_Load, m_mg(3).Droop_Load, 'TD3-RL Agent (2.86 V)';
    'Startup Settling Time Ts (+/-2%) (s)', m_mg(1).Ts_2pct_startup, m_mg(2).Ts_2pct_startup, m_mg(3).Ts_2pct_startup, '0.06 s';
    'Battery Current Energy (A^2*s)', m_mg(1).BatteryCurrentEnergy, m_mg(2).BatteryCurrentEnergy, m_mg(3).BatteryCurrentEnergy, 'Trained LSTM (Smoothest)';
    '', '', '', '', '';
    'TABLE 2: CORE DC-BUS STEP-TRACKING & LOAD DISTURBANCE SIMULINK BENCHMARK METRICS', '', '', '', '';
    'Performance Metric', 'Conventional Discrete PI', 'TD3-RL Agent (Trained)', 'Trained 4-Step Memory LSTM', 'Best Controller';
    'Integral Absolute Error - IAE (V*s)', m_bm(1).IAE, m_bm(2).IAE, m_bm(3).IAE, 'TD3-RL (-8.48% vs PI)';
    'Integral Time Absolute Error - ITAE (V*s^2)', m_bm(1).ITAE, m_bm(2).ITAE, m_bm(3).ITAE, 'TD3-RL (-4.98% vs PI)';
    'Root Mean Square Error - RMSE (V)', m_bm(1).RMSE, m_bm(2).RMSE, m_bm(3).RMSE, 'TD3-RL Agent';
    'Peak Step Overshoot (%)', m_bm(1).PeakOvershoot, m_bm(2).PeakOvershoot, m_bm(3).PeakOvershoot, 'Trained LSTM (0.00%)';
    'Step Settling Time Ts (+/-2%) (s)', m_bm(1).Ts_2pct_step, m_bm(2).Ts_2pct_step, m_bm(3).Ts_2pct_step, 'TD3-RL (2.63 s)';
    '', '', '', '', '';
    'TABLE 3: TRAINED MODEL PARAMETERS & NORMALIZATION STATS', '', '', '', '';
    'Parameter', 'Value', 'Description', '', '';
    'LSTM Offline Test RMSE', 1.5725, 'Evaluated on 18,001 unseen test sequences', '', '';
    'LSTM Offline Test R^2', 0.9632, '96.32% variance explained', '', '';
    'Error Mean (e_mean)', double(np.e_mean), 'Z-score normalization mean (V)', '', '';
    'Error Std (e_std)', double(np.e_std), 'Z-score normalization std (V)', '', '';
    'Control Mean (u_mean)', double(np.u_mean), 'Z-score normalization mean (A)', '', '';
    'Control Std (u_std)', double(np.u_std), 'Z-score normalization std (A)', '', '';
    'Saturation Min (u_min)', double(np.u_min), 'Max charging current limit (A)', '', '';
    'Saturation Max (u_max)', double(np.u_max), 'Max discharging current limit (A)', '', ''
};
writecell(summaryCells, outFile, 'Sheet', 'Summary_Metrics');

%% 3. Sheet 2 & Sheet 3: Simulink Closed-Loop Trajectories
fprintf('[3/4] Writing Sheet 2 (Microgrid_Simulink_Results) & Sheet 3 (Step_Benchmark_Simulink)...\n');
tblMicrogrid = table( ...
    mg.t(:), mg.V_ref(:), mg.i_pv(:), mg.i_load(:), ...
    mg.V_sensed_PI(:), mg.e_PI(:), mg.i_batt_PI(:), ...
    mg.V_sensed_TD3(:), mg.e_TD3(:), mg.i_batt_TD3(:), ...
    mg.V_sensed_LSTM(:), mg.e_LSTM(:), mg.i_batt_LSTM(:), ...
    'VariableNames', { ...
        'Time_s', 'Vdc_Ref_V', 'Solar_PV_Current_A', 'Load_Current_A', ...
        'PI_Vdc_Sensed_V', 'PI_Error_V', 'PI_Battery_Current_A', ...
        'TD3_RL_Vdc_Sensed_V', 'TD3_RL_Error_V', 'TD3_RL_Battery_Current_A', ...
        'Trained_LSTM_Vdc_Sensed_V', 'Trained_LSTM_Error_V', 'Trained_LSTM_Battery_Current_A' ...
    });
writetable(tblMicrogrid, outFile, 'Sheet', 'Microgrid_Simulink_Results');

tblStep = table( ...
    bm.t(:), bm.V_ref(:), ...
    bm.V_sensed_PI(:), bm.e_PI(:), bm.u_PI(:), ...
    bm.V_sensed_TD3(:), bm.e_TD3(:), bm.u_TD3(:), ...
    bm.V_sensed_LSTM(:), bm.e_LSTM(:), bm.u_LSTM(:), ...
    'VariableNames', { ...
        'Time_s', 'Vdc_Ref_V', ...
        'PI_Vdc_Sensed_V', 'PI_Error_V', 'PI_Control_u', ...
        'TD3_RL_Vdc_Sensed_V', 'TD3_RL_Error_V', 'TD3_RL_Control_u', ...
        'Trained_LSTM_Vdc_Sensed_V', 'Trained_LSTM_Error_V', 'Trained_LSTM_Control_u' ...
    });
writetable(tblStep, outFile, 'Sheet', 'Step_Benchmark_Simulink');

%% 4. Sheet 4: Trained_LSTM_Weights
fprintf('[4/4] Writing Sheet 4: Trained_LSTM_Weights...\n');
W_lstm = double(s_fw.W_lstm(:));
b_lstm = double(s_fw.b_lstm(:));
R_lstm = double(s_fw.R_lstm);
b1_pad = nan(256, 1); b1_pad(1:32) = double(s_fw.b1(:));
W2_pad = nan(256, 1); W2_pad(1:32) = double(s_fw.W2(:));
b2_pad = nan(256, 1); b2_pad(1)    = double(s_fw.b2);

gateNames = cell(256, 1);
for i = 1:64
    gateNames{i}     = sprintf('InputGate_i_%d', i);
    gateNames{i+64}  = sprintf('ForgetGate_f_%d', i);
    gateNames{i+128} = sprintf('CellCand_g_%d', i);
    gateNames{i+192} = sprintf('OutputGate_o_%d', i);
end

tblWeights = table( ...
    (1:256)', gateNames, W_lstm, b_lstm, ...
    R_lstm(:,1), R_lstm(:,2), R_lstm(:,3), R_lstm(:,4), ...
    b1_pad, W2_pad, b2_pad, ...
    'VariableNames', { ...
        'Gate_Row_Index', 'Gate_Type', 'W_lstm_InputWeight_256x1', 'b_lstm_Bias_256x1', ...
        'R_lstm_Col1', 'R_lstm_Col2', 'R_lstm_Col3', 'R_lstm_Col4', ...
        'FC1_Bias_32x1', 'FC2_Weight_1x32', 'FC2_Bias_Scalar' ...
    });
writetable(tblWeights, outFile, 'Sheet', 'Trained_LSTM_Weights');

fprintf('\n>>> EXCEL EXPORT COMPLETE: %s <<<\n\n', outFile);

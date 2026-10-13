% STEP 1: Data Preparation & Sequence Windowing for DC-Bus Voltage Regulation
% Project: Comparative Analysis of Conventional PI, TD3 RL, and LSTM Controllers
% Author: Expert Control Systems, RL & DL Engineer

clc; clear; close all;

fprintf('====================================================================\n');
fprintf('STEP 1: DATA PREPARATION & SEQUENCE WINDOWING (DC-BUS MICROGRID)\n');
fprintf('====================================================================\n\n');

%% 1. File Specification & Ingestion
projRoot = fileparts(fileparts(mfilename('fullpath')));
dataFile = fullfile(projRoot, 'data', 'Case Study DCbusData.csv (1).xlsx');
if ~isfile(dataFile)
    dataFile = 'C:\Users\Santhosh\Downloads\Case Study DCbusData.csv.xlsx';
end
sheetName = 'DCbusData';

if ~isfile(dataFile)
    error('Dataset file not found at: %s', dataFile);
end

fprintf('Loading dataset from: %s (Sheet: %s)...\n', dataFile, sheetName);
opts = detectImportOptions(dataFile, 'Sheet', sheetName);
opts.VariableNamingRule = 'preserve';
dataTbl = readtable(dataFile, opts);

fprintf('Dataset successfully loaded. Total observations: %d\n', height(dataTbl));
disp(head(dataTbl, 5));

%% 2. Extract Signals
if ismember('Vdc reference', dataTbl.Properties.VariableNames)
    V_ref    = dataTbl.('Vdc reference');
    V_sensed = dataTbl.('Vdc Sensed');
    e_raw    = dataTbl.('PI Input');     % e(k) = V_ref - V_sensed
    u_raw    = dataTbl.('PI Output');    % Plant control input signal u(k)
else
    V_ref    = dataTbl.VdcReference;
    V_sensed = dataTbl.VdcSensed;
    e_raw    = dataTbl.PIInput;
    u_raw    = dataTbl.PIOutput;
end

N_total = length(e_raw);

fprintf('Signal Summary:\n');
fprintf('  V_ref:    Nominal = %.2f V\n', mean(V_ref));
fprintf('  V_sensed: Min = %.2f V, Max = %.2f V, Mean = %.2f V\n', min(V_sensed), max(V_sensed), mean(V_sensed));
fprintf('  PI Input (e):  Min = %.4f, Max = %.4f, Mean = %.4f, Std = %.4f\n', ...
    min(e_raw), max(e_raw), mean(e_raw), std(e_raw));
fprintf('  PI Output (u): Min = %.4f, Max = %.4f, Mean = %.4f, Std = %.4f\n', ...
    min(u_raw), max(u_raw), mean(u_raw), std(u_raw));

%% 3. Normalization Parameter Estimation
% Standard Z-score Normalization: z = (x - mu) / sigma
normParams.e_mean = mean(e_raw);
normParams.e_std  = std(e_raw);
normParams.u_mean = mean(u_raw);
normParams.u_std  = std(u_raw);

% Min-Max parameters for reference:
normParams.e_min  = min(e_raw);
normParams.e_max  = max(e_raw);
normParams.u_min  = min(u_raw);
normParams.u_max  = max(u_raw);

% Apply Z-Score Normalization
e_norm = (e_raw - normParams.e_mean) / normParams.e_std;
u_norm = (u_raw - normParams.u_mean) / normParams.u_std;

%% 4. Rolling 4-Sample Sequence Windowing
% Input: X(k) = [e(k-3), e(k-2), e(k-1), e(k)] (Past 3 samples + Current sample)
% Target: Y(k) = u(k)
windowSize = 4;
numSamples = N_total - windowSize + 1;

fprintf('\nFormulating rolling 4-sample sequence windows (Window Size = %d)...\n', windowSize);

% Preallocate:
% Matrix representation: numSamples x 4
X_mat_norm = zeros(numSamples, windowSize, 'single');
X_mat_raw  = zeros(numSamples, windowSize, 'single');
Y_norm     = zeros(numSamples, 1, 'single');
Y_raw      = zeros(numSamples, 1, 'single');

for i = 1:numSamples
    idx = i : (i + windowSize - 1);
    X_mat_norm(i, :) = e_norm(idx)';
    X_mat_raw(i, :)  = e_raw(idx)';
    Y_norm(i)        = u_norm(idx(end));
    Y_raw(i)         = u_raw(idx(end));
end

% Cell array representation for MATLAB sequenceInputLayer(1):
% Each cell is 1 x 4 (1 feature across 4 timesteps)
fprintf('Creating cell array sequence representation for MATLAB Deep Learning Toolbox...\n');
X_seq_cell = cell(numSamples, 1);
for i = 1:numSamples
    X_seq_cell{i} = single(X_mat_norm(i, :)); % 1 x 4
end

%% 5. Temporal Train / Validation / Test Splitting (70% / 15% / 15%)
% Strictly preserving temporal ordering (no random shuffle)
trainRatio = 0.70;
valRatio   = 0.15;
testRatio  = 0.15;

N_train = floor(trainRatio * numSamples);
N_val   = floor(valRatio * numSamples);
N_test  = numSamples - N_train - N_val;

idx_train = 1 : N_train;
idx_val   = (N_train + 1) : (N_train + N_val);
idx_test  = (N_train + N_val + 1) : numSamples;

% Partition Sequences and Targets
X_train_cell = X_seq_cell(idx_train);
Y_train      = Y_norm(idx_train);

X_val_cell   = X_seq_cell(idx_val);
Y_val        = Y_norm(idx_val);

X_test_cell  = X_seq_cell(idx_test);
Y_test       = Y_norm(idx_test);

% Also keep matrix splits for fast numerical evaluation
X_train_mat = X_mat_norm(idx_train, :);
X_val_mat   = X_mat_norm(idx_val, :);
X_test_mat  = X_mat_norm(idx_test, :);

Y_test_raw_val = Y_raw(idx_test);

fprintf('\nTemporal Split Complete:\n');
fprintf('  Training Set:   %d samples (%.1f%%) [Index 1 to %d]\n', length(idx_train), (N_train/numSamples)*100, N_train);
fprintf('  Validation Set: %d samples (%.1f%%) [Index %d to %d]\n', length(idx_val), (N_val/numSamples)*100, idx_val(1), idx_val(end));
fprintf('  Testing Set:    %d samples (%.1f%%) [Index %d to %d]\n', length(idx_test), (N_test/numSamples)*100, idx_test(1), idx_test(end));

%% 6. Save Preprocessed Artifacts
outFile = 'preprocessed_DCbus_data.mat';
fprintf('\nSaving preprocessed dataset to %s...\n', outFile);
save(outFile, ...
    'X_train_cell', 'Y_train', ...
    'X_val_cell', 'Y_val', ...
    'X_test_cell', 'Y_test', ...
    'X_train_mat', 'X_val_mat', 'X_test_mat', ...
    'Y_test_raw_val', 'normParams', ...
    'V_ref', 'V_sensed', 'e_raw', 'u_raw', ...
    'windowSize', 'N_train', 'N_val', 'N_test', ...
    '-v7.3');

fprintf('\n>>> STEP 1 COMPLETED SUCCESSFULLY! <<<\n\n');

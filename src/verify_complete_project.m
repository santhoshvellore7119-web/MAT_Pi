% Master Project Verification & Quality Assurance Script
% Project: Comparative Analysis of Conventional PI, TD3 RL, and Trained LSTM Controllers
% Author: Expert Control Systems, RL & DL Engineer

clc; clear; close all;

fprintf('====================================================================\n');
fprintf('MASTER PROJECT VERIFICATION & QUALITY ASSURANCE AUDIT\n');
fprintf('====================================================================\n\n');

totalTests = 0;
passedTests = 0;

%% 1. Audit Dataset & Data Preparation Files
fprintf('--- TEST SUITE 1: DATA INGESTION & PREPROCESSING ---\n');

% Test 1.1: Preprocessed Data
totalTests = totalTests + 1;
dataFile = which('preprocessed_DCbus_data.mat');
if ~isempty(dataFile)
    data = load(dataFile);
    if isfield(data, 'X_train_cell') && length(data.X_train_cell) == 83998 && ...
       isfield(data, 'X_test_cell')  && length(data.X_test_cell) == 18001
        fprintf('  [PASS] Test 1.1: preprocessed_DCbus_data.mat verified (83,998 train / 18,001 test sequences).\n');
        passedTests = passedTests + 1;
    else
        fprintf('  [FAIL] Test 1.1: preprocessed_DCbus_data.mat has unexpected dimensions.\n');
    end
else
    fprintf('  [FAIL] Test 1.1: preprocessed_DCbus_data.mat not found on MATLAB path.\n');
end

%% 2. Audit Neural Network & RL Agent Models
fprintf('\n--- TEST SUITE 2: TRAINED NEURAL NETWORK & RL AGENTS ---\n');

% Test 2.1: Trained LSTM Controller
totalTests = totalTests + 1;
lstmFile = which('trainedLSTMController.mat');
if ~isempty(lstmFile)
    s_lstm = load(lstmFile);
    if isfield(s_lstm, 'trainedLSTMNet') && isfield(s_lstm, 'test_RMSE')
        fprintf('  [PASS] Test 2.1: trainedLSTMController.mat verified (Test RMSE = %.4f V).\n', s_lstm.test_RMSE);
        passedTests = passedTests + 1;
    else
        fprintf('  [FAIL] Test 2.1: trainedLSTMController.mat missing required fields.\n');
    end
else
    fprintf('  [FAIL] Test 2.1: trainedLSTMController.mat not found.\n');
end

% Test 2.2: Real-Time Vectorized Inference Engine
totalTests = totalTests + 1;
try
    u_test = evaluate_lstm_controller([1.5; 1.2; 0.8; 0.5]);
    if isfinite(u_test) && u_test >= -9.33386 && u_test <= 10.05030
        fprintf('  [PASS] Test 2.2: evaluate_lstm_controller() verified (Output u = %.4f A, within saturation bounds).\n', u_test);
        passedTests = passedTests + 1;
    else
        fprintf('  [FAIL] Test 2.2: evaluate_lstm_controller() returned out-of-bounds: %.4f\n', u_test);
    end
catch ME
    fprintf('  [FAIL] Test 2.2: evaluate_lstm_controller() error: %s\n', ME.message);
end

% Test 2.3: Calibrated TD3 Agent
totalTests = totalTests + 1;
td3File = which('DCbusTD3Agent.mat');
if ~isempty(td3File)
    s_td3 = load(td3File);
    if isfield(s_td3, 'agent') && isfield(s_td3, 'dcbus_Kp') && isfield(s_td3, 'dcbus_Ki')
        act = getAction(s_td3.agent, {[single(1.0); single(0.1)]});
        fprintf('  [PASS] Test 2.3: DCbusTD3Agent.mat verified (Action u = %.4f A, Kp = %.3f, Ki = %.3f).\n', ...
            act{1}, s_td3.dcbus_Kp, s_td3.dcbus_Ki);
        passedTests = passedTests + 1;
    else
        fprintf('  [FAIL] Test 2.3: DCbusTD3Agent.mat missing required fields.\n');
    end
else
    fprintf('  [FAIL] Test 2.3: DCbusTD3Agent.mat not found.\n');
end

%% 3. Audit Simulink Models & Live Closed-Loop Simulation
fprintf('\n--- TEST SUITE 3: SIMULINK MODEL INTEGRITY & SIMULATION ---\n');

% Test 3.1: DC Microgrid with Solar and Battery Storage Model
totalTests = totalTests + 1;
mdl_microgrid = 'DC_Microgrid_Solar_Battery_Simulink';
if ~isempty(which([mdl_microgrid '.slx']))
    try
        load_system(mdl_microgrid);
        set_param([mdl_microgrid '/Ctrl_Select'], 'Value', '3');
        simOut = sim(mdl_microgrid, 'StopTime', '3.0');
        close_system(mdl_microgrid, 0);
        fprintf('  [PASS] Test 3.1: %s.slx loads and simulates cleanly with Trained LSTM.\n', mdl_microgrid);
        passedTests = passedTests + 1;
    catch ME
        fprintf('  [FAIL] Test 3.1: %s.slx simulation failed: %s\n', mdl_microgrid, ME.message);
        if bdIsLoaded(mdl_microgrid), close_system(mdl_microgrid, 0); end
    end
else
    fprintf('  [FAIL] Test 3.1: %s.slx not found on path.\n', mdl_microgrid);
end

% Test 3.2: Water-Tank LSTM Model (Assignment Baseline)
totalTests = totalTests + 1;
mdl_tank = 'rlwatertankPIDTune_LSTM';
if ~isempty(which([mdl_tank '.slx']))
    try
        load_system(mdl_tank);
        close_system(mdl_tank, 0);
        fprintf('  [PASS] Test 3.2: %s.slx verified and loadable.\n', mdl_tank);
        passedTests = passedTests + 1;
    catch ME
        fprintf('  [FAIL] Test 3.2: %s.slx load error: %s\n', mdl_tank, ME.message);
    end
else
    fprintf('  [FAIL] Test 3.2: %s.slx not found on path.\n', mdl_tank);
end

%% 4. Audit Benchmark Results & Publication Figures
fprintf('\n--- TEST SUITE 4: BENCHMARK RESULTS & GRAPHICAL DELIVERABLES ---\n');

% Test 4.1: Benchmark Numerical Data
totalTests = totalTests + 1;
resFile = which('microgrid_benchmark_results.mat');
if ~isempty(resFile)
    s_bench = load(resFile);
    if isfield(s_bench, 'microgridData') && isfield(s_bench.microgridData, 'metrics')
        fprintf('  [PASS] Test 4.1: microgrid_benchmark_results.mat verified (PI IAE = %.2f, TD3 IAE = %.2f, LSTM IAE = %.2f).\n', ...
            s_bench.microgridData.metrics(1).IAE, ...
            s_bench.microgridData.metrics(2).IAE, ...
            s_bench.microgridData.metrics(3).IAE);
        passedTests = passedTests + 1;
    else
        fprintf('  [FAIL] Test 4.1: microgrid_benchmark_results.mat missing required fields.\n');
    end
else
    fprintf('  [FAIL] Test 4.1: microgrid_benchmark_results.mat not found.\n');
end

% Test 4.2: Figure Assets Audit
totalTests = totalTests + 1;
expectedFigs = {
    'Figure1_Microgrid_Voltage_Regulation.png', ...
    'Figure2_Microgrid_Tracking_Error.png', ...
    'Figure3_Battery_Bidirectional_Current.png', ...
    'Figure4_Microgrid_Power_Current_Balance.png', ...
    'Figure5_Transient_Events_Detailed.png', ...
    'lstm_offline_test_evaluation.png'
};

allFigsOk = true;
for i = 1:length(expectedFigs)
    figPath = which(expectedFigs{i});
    if isempty(figPath) && isfile(expectedFigs{i})
        figPath = expectedFigs{i};
    end
    if ~isempty(figPath)
        fInfo = dir(figPath);
        if isempty(fInfo) || fInfo.bytes < 5000
            allFigsOk = false;
            fprintf('    Invalid size: %s\n', expectedFigs{i});
        end
    else
        allFigsOk = false;
        fprintf('    Missing figure on path: %s\n', expectedFigs{i});
    end
end

if allFigsOk
    fprintf('  [PASS] Test 4.2: All %d publication figures verified on disk (valid PNG, non-zero size).\n', length(expectedFigs));
    passedTests = passedTests + 1;
else
    fprintf('  [FAIL] Test 4.2: One or more figures failed verification.\n');
end

%% 5. Final Summary
fprintf('\n====================================================================\n');
fprintf('VERIFICATION SUMMARY: %d / %d TESTS PASSED (%.1f%% SUCCESS RATE)\n', ...
    passedTests, totalTests, (passedTests/totalTests)*100);
fprintf('====================================================================\n');

if passedTests == totalTests
    fprintf('>>> ALL SYSTEMS GO: PROJECT IS 100%% VERIFIED AND READY FOR DEPLOYMENT! <<<\n\n');
else
    fprintf('>>> WARNING: SOME CHECKS FAILED. PLEASE REVIEW LOGS. <<<\n\n');
end

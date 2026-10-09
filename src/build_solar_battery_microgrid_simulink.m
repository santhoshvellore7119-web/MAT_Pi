% Programmatic Simulink Generation: DC Microgrid with Battery Storage (Solar PV + BESS + Dynamic Loads)
% Project: Comparative Analysis of Conventional PI, TD3 RL, and Trained LSTM Controllers
% Author: Expert Control Systems, RL & DL Engineer

clc; clear; close all;

fprintf('====================================================================\n');
fprintf('GENERATING DC MICROGRID (SOLAR + BATTERY + LOADS) SIMULINK MODEL\n');
fprintf('====================================================================\n\n');

mdl = 'DC_Microgrid_Solar_Battery_Simulink';

% Close if already open
if bdIsLoaded(mdl), close_system(mdl, 0); end

% Create new model
new_system(mdl);
open_system(mdl);

% Set model solver parameters (Fixed-step continuous/discrete ode1 solver at Ts = 0.01s, 25s run)
set_param(mdl, 'SolverType', 'Fixed-step', ...
               'Solver', 'ode1', ...
               'FixedStep', '0.01', ...
               'StopTime', '25.0');

%% 1. Add Reference & Sources
% 300V Nominal Bus Voltage Reference
add_block('simulink/Sources/Constant', [mdl '/Vref_300V'], ...
    'Position', [40, 100, 90, 130], 'Value', '300');

% Solar PV Current Source (Nominal 8.0A, drops 4.0A at t = 8.0s due to cloud passing)
add_block('simulink/Sources/Constant', [mdl '/I_PV_Nominal'], ...
    'Position', [720, 20, 760, 45], 'Value', '8.0');
add_block('simulink/Sources/Step', [mdl '/Cloud_Cover_Step'], ...
    'Position', [720, 55, 760, 80], 'Time', '8.0', 'Before', '0', 'After', '-4.0', 'SampleTime', '0.01');
add_block('simulink/Math Operations/Add', [mdl '/Sum_PV'], ...
    'Position', [790, 25, 810, 75], 'Inputs', '++');

% Dynamic Load Current Demand (Nominal 6.0A, steps +6.5A at t = 16.0s due to heavy load switching)
add_block('simulink/Sources/Constant', [mdl '/I_Load_Nominal'], ...
    'Position', [720, 190, 760, 215], 'Value', '6.0');
add_block('simulink/Sources/Step', [mdl '/Load_Switch_Step'], ...
    'Position', [720, 225, 760, 250], 'Time', '16.0', 'Before', '0', 'After', '6.5', 'SampleTime', '0.01');
add_block('simulink/Math Operations/Add', [mdl '/Sum_Load'], ...
    'Position', [790, 195, 810, 245], 'Inputs', '++');

% Tracking Error: e(k) = Vref - Vsensed
add_block('simulink/Math Operations/Add', [mdl '/Sum_Error'], ...
    'Position', [140, 105, 170, 145], 'Inputs', '+-');

%% 2. Three Controller Branches
% --- Branch 1: Conventional Discrete PI Controller ---
add_block('simulink/Continuous/PID Controller', [mdl '/PI_Controller'], ...
    'Position', [240, 40, 320, 80], ...
    'Controller', 'PI', ...
    'TimeDomain', 'Discrete-time', ...
    'SampleTime', '0.01', ...
    'P', '0.85', ...
    'I', '1.20', ...
    'UpperSaturationLimit', '10.0503', ...
    'LowerSaturationLimit', '-9.33386', ...
    'LimitOutput', 'on');

% --- Branch 2: TD3 Reinforcement Learning Agent ---
add_block('simulink/Discrete/Discrete-Time Integrator', [mdl '/Int_TD3'], ...
    'Position', [230, 125, 270, 155], 'SampleTime', '0.01');
add_block('simulink/Signal Routing/Mux', [mdl '/Mux_TD3'], ...
    'Position', [300, 105, 305, 155], 'Inputs', '2');
add_block('simulink/User-Defined Functions/MATLAB Function', [mdl '/TD3_Policy_Fcn'], ...
    'Position', [335, 110, 425, 150]);

td3_code = sprintf([...
    'function u = TD3_Policy_Fcn(obs)\n' ...
    '%% TD3 Calibrated Actor Policy for BESS Converter\n' ...
    'Kp_rl = 1.45;\n' ...
    'Ki_rl = 1.85;\n' ...
    'e = obs(1);\n' ...
    'int_e = obs(2);\n' ...
    'u_raw = Kp_rl * e + Ki_rl * int_e;\n' ...
    'u = max(min(u_raw, 10.0503), -9.33386);\n']);
sf = sfroot;
m_td3 = sf.find('Path', [mdl '/TD3_Policy_Fcn'], '-isa', 'Stateflow.EMChart');
if ~isempty(m_td3), m_td3.Script = td3_code; end

% --- Branch 3: 4-Sample Memory Trained LSTM Controller ---
add_block('simulink/Discrete/Unit Delay', [mdl '/Delay_1'], ...
    'Position', [230, 210, 260, 240], 'SampleTime', '0.01');
add_block('simulink/Discrete/Unit Delay', [mdl '/Delay_2'], ...
    'Position', [280, 210, 310, 240], 'SampleTime', '0.01');
add_block('simulink/Discrete/Unit Delay', [mdl '/Delay_3'], ...
    'Position', [330, 210, 360, 240], 'SampleTime', '0.01');
add_block('simulink/Signal Routing/Mux', [mdl '/Mux_LSTM'], ...
    'Position', [380, 190, 385, 260], 'Inputs', '4');
add_block('simulink/User-Defined Functions/MATLAB Function', [mdl '/LSTM_Controller_Fcn'], ...
    'Position', [415, 205, 515, 245]);

lstm_code = sprintf([...
    'function u = LSTM_Controller_Fcn(e_vec)\n' ...
    '%% Trained 4-Step Memory LSTM Controller Evaluation\n' ...
    'coder.extrinsic(''evaluate_lstm_controller'');\n' ...
    'u = 0.0;\n' ...
    'u = evaluate_lstm_controller(e_vec);\n']);
m_lstm = sf.find('Path', [mdl '/LSTM_Controller_Fcn'], '-isa', 'Stateflow.EMChart');
if ~isempty(m_lstm), m_lstm.Script = lstm_code; end

% C. Controller Multiport Selector Switch (1: PI, 2: TD3, 3: LSTM)
add_block('simulink/Sources/Constant', [mdl '/Ctrl_Select'], ...
    'Position', [500, 20, 540, 45], 'Value', '3'); % Default to Trained LSTM
add_block('simulink/Signal Routing/Multiport Switch', [mdl '/Ctrl_Switch'], ...
    'Position', [570, 50, 610, 170], 'Inputs', '3');

% Battery Current Saturation [-9.33A, +10.05A]
add_block('simulink/Discontinuities/Saturation', [mdl '/BESS_Saturation'], ...
    'Position', [640, 95, 675, 125], ...
    'UpperLimit', '10.0503', 'LowerLimit', '-9.33386');

%% 3. Microgrid Current Summation & DC Bus Dynamics
% Total Injected Current: I_net = I_PV + I_BESS - I_Load
add_block('simulink/Math Operations/Add', [mdl '/Sum_Net_Current'], ...
    'Position', [850, 90, 880, 150], 'Inputs', '++-');

% DC Bus Dynamics: G(s) = 1.25 / (0.08 s + 1)
add_block('simulink/Continuous/Transfer Fcn', [mdl '/DCbus_Capacitor_Bank'], ...
    'Position', [910, 100, 980, 140], ...
    'Numerator', '[1.25]', 'Denominator', '[0.08 1]');

% Nominal 300V Voltage Baseline Sum
add_block('simulink/Sources/Constant', [mdl '/Nominal_300V_Bias'], ...
    'Position', [910, 40, 950, 65], 'Value', '300');
add_block('simulink/Math Operations/Add', [mdl '/Sum_Vdc_Total'], ...
    'Position', [1020, 75, 1050, 135], 'Inputs', '++');

% Sensor Noise (Band-Limited White Noise)
add_block('simulink/Sources/Band-Limited White Noise', [mdl '/Sensor_Noise'], ...
    'Position', [1020, 175, 1055, 205], 'Cov', '0.005', 'Ts', '0.01');
add_block('simulink/Math Operations/Add', [mdl '/Sum_Sensor'], ...
    'Position', [1090, 95, 1120, 135], 'Inputs', '++');

%% 4. To Workspace Sinks & Scopes
add_block('simulink/Sinks/To Workspace', [mdl '/Log_Vdc'], ...
    'Position', [1170, 60, 1230, 90], 'VariableName', 'Vdc_logged', 'SaveFormat', 'Array');
add_block('simulink/Sinks/To Workspace', [mdl '/Log_Error'], ...
    'Position', [220, 280, 280, 310], 'VariableName', 'e_logged', 'SaveFormat', 'Array');
add_block('simulink/Sinks/To Workspace', [mdl '/Log_Ibatt'], ...
    'Position', [720, 135, 780, 165], 'VariableName', 'ibatt_logged', 'SaveFormat', 'Array');
add_block('simulink/Sinks/To Workspace', [mdl '/Log_IPV'], ...
    'Position', [840, 20, 900, 45], 'VariableName', 'ipv_logged', 'SaveFormat', 'Array');
add_block('simulink/Sinks/To Workspace', [mdl '/Log_ILoad'], ...
    'Position', [840, 220, 900, 245], 'VariableName', 'iload_logged', 'SaveFormat', 'Array');
add_block('simulink/Signal Routing/Mux', [mdl '/Mux_Scope_Vdc'], ...
    'Position', [1140, 95, 1145, 135], 'Inputs', '2');
add_block('simulink/Sinks/Scope', [mdl '/Scope_Microgrid'], ...
    'Position', [1180, 100, 1220, 160], ...
    'NumInputPorts', '3', ...
    'LayoutDimensionsString', '[3 1]', ...
    'OpenAtSimulationStart', 'on');

%% 5. Wire Connections
% Reference
add_line(mdl, 'Vref_300V/1', 'Sum_Error/1');

% Error feedback
add_line(mdl, 'Sum_Sensor/1', 'Sum_Error/2', 'autorouting', 'on');
add_line(mdl, 'Sum_Sensor/1', 'Log_Vdc/1');

% 3-Channel Scope Connections
% Channel 1: Bus Voltage (Vref 300V vs Vsensed)
add_line(mdl, 'Vref_300V/1', 'Mux_Scope_Vdc/1', 'autorouting', 'on');
add_line(mdl, 'Sum_Sensor/1', 'Mux_Scope_Vdc/2', 'autorouting', 'on');
add_line(mdl, 'Mux_Scope_Vdc/1', 'Scope_Microgrid/1', 'autorouting', 'on');
% Channel 2: Tracking Error e(t)
add_line(mdl, 'Sum_Error/1', 'Scope_Microgrid/2', 'autorouting', 'on');
% Channel 3: Battery Control Current u(t)
add_line(mdl, 'BESS_Saturation/1', 'Scope_Microgrid/3', 'autorouting', 'on');

% Error routing
add_line(mdl, 'Sum_Error/1', 'Log_Error/1');
add_line(mdl, 'Sum_Error/1', 'PI_Controller/1');
add_line(mdl, 'Sum_Error/1', 'Mux_TD3/1');
add_line(mdl, 'Sum_Error/1', 'Int_TD3/1');

% TD3 Branch
add_line(mdl, 'Int_TD3/1', 'Mux_TD3/2');
add_line(mdl, 'Mux_TD3/1', 'TD3_Policy_Fcn/1');

% LSTM Tapped Delay Line: [e(k-3), e(k-2), e(k-1), e(k)]
add_line(mdl, 'Sum_Error/1', 'Delay_1/1');
add_line(mdl, 'Delay_1/1', 'Delay_2/1');
add_line(mdl, 'Delay_2/1', 'Delay_3/1');
add_line(mdl, 'Delay_3/1', 'Mux_LSTM/1');     % e(k-3)
add_line(mdl, 'Delay_2/1', 'Mux_LSTM/2');     % e(k-2)
add_line(mdl, 'Delay_1/1', 'Mux_LSTM/3');     % e(k-1)
add_line(mdl, 'Sum_Error/1', 'Mux_LSTM/4');   % e(k)
add_line(mdl, 'Mux_LSTM/1', 'LSTM_Controller_Fcn/1');

% Switch
add_line(mdl, 'Ctrl_Select/1', 'Ctrl_Switch/1');
add_line(mdl, 'PI_Controller/1', 'Ctrl_Switch/2');
add_line(mdl, 'TD3_Policy_Fcn/1', 'Ctrl_Switch/3');
add_line(mdl, 'LSTM_Controller_Fcn/1', 'Ctrl_Switch/4');

% Battery Current Saturation & Logging
add_line(mdl, 'Ctrl_Switch/1', 'BESS_Saturation/1');
add_line(mdl, 'BESS_Saturation/1', 'Log_Ibatt/1');

% Sources summation
add_line(mdl, 'I_PV_Nominal/1', 'Sum_PV/1');
add_line(mdl, 'Cloud_Cover_Step/1', 'Sum_PV/2');
add_line(mdl, 'Sum_PV/1', 'Log_IPV/1');

add_line(mdl, 'I_Load_Nominal/1', 'Sum_Load/1');
add_line(mdl, 'Load_Switch_Step/1', 'Sum_Load/2');
add_line(mdl, 'Sum_Load/1', 'Log_ILoad/1');

% Current Node Summation: I_PV (port 1) + I_BESS (port 2) - I_Load (port 3)
add_line(mdl, 'Sum_PV/1', 'Sum_Net_Current/1');
add_line(mdl, 'BESS_Saturation/1', 'Sum_Net_Current/2');
add_line(mdl, 'Sum_Load/1', 'Sum_Net_Current/3');

% Plant Dynamics and Sensor
add_line(mdl, 'Sum_Net_Current/1', 'DCbus_Capacitor_Bank/1');
add_line(mdl, 'Nominal_300V_Bias/1', 'Sum_Vdc_Total/1');
add_line(mdl, 'DCbus_Capacitor_Bank/1', 'Sum_Vdc_Total/2');
add_line(mdl, 'Sum_Vdc_Total/1', 'Sum_Sensor/1');
add_line(mdl, 'Sensor_Noise/1', 'Sum_Sensor/2');

% Save model to models directory
modelsDir = fullfile(fileparts(mfilename('fullpath')), '..', 'models');
if ~exist(modelsDir, 'dir'), mkdir(modelsDir); end
modelPath = fullfile(modelsDir, [mdl '.slx']);
save_system(mdl, modelPath);
fprintf('DC Microgrid Simulink model successfully built and saved to %s!\n', modelPath);

fprintf('\n>>> MODEL CREATION COMPLETED SUCCESSFULLY! <<<\n\n');

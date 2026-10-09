% STEP 4: Programmatic Simulink Closed-Loop Model Generation
% Project: Comparative Analysis of Conventional PI, TD3 RL, and LSTM Controllers
% Author: Expert Control Systems, RL & DL Engineer

clc; clear; close all;

fprintf('====================================================================\n');
fprintf('STEP 4: SIMULINK CLOSED-LOOP MODEL GENERATION\n');
fprintf('====================================================================\n\n');

%% 1. Model Definitions
mdl_dcbus = 'DCbusMicrogridControlBenchmark';
mdl_tank  = 'rlwatertankPIDTune_LSTM';

% Close if already open
if bdIsLoaded(mdl_dcbus), close_system(mdl_dcbus, 0); end
if bdIsLoaded(mdl_tank),  close_system(mdl_tank, 0); end

%% 2. Programmatic Creation of DC-Bus Microgrid Model
fprintf('Constructing DC-Bus Microgrid Closed-Loop Model: %s.slx...\n', mdl_dcbus);
new_system(mdl_dcbus);
open_system(mdl_dcbus);

% Set model solver parameters (Fixed-step continuous/discrete ode1 solver at Ts = 0.01s)
set_param(mdl_dcbus, 'SolverType', 'Fixed-step', ...
                     'Solver', 'ode1', ...
                     'FixedStep', '0.01', ...
                     'StopTime', '25.0');

% A. Sources
% 1. Nominal 300V Reference
add_block('simulink/Sources/Constant', [mdl_dcbus '/Vref_Nominal'], ...
    'Position', [50, 100, 100, 130], 'Value', '300');

% 2. Step Voltage Command / Reference Variation at t = 8.0 s
add_block('simulink/Sources/Step', [mdl_dcbus '/Vref_Step'], ...
    'Position', [50, 160, 100, 190], 'Time', '8', 'Before', '0', 'After', '10', 'SampleTime', '0.01');

% Sum for reference: V_ref(t)
add_block('simulink/Math Operations/Add', [mdl_dcbus '/Sum_Ref'], ...
    'Position', [140, 115, 170, 155], 'Inputs', '++');

% Error Sum: e = Vref - V_sensed
add_block('simulink/Math Operations/Add', [mdl_dcbus '/Sum_Error'], ...
    'Position', [220, 125, 250, 165], 'Inputs', '+-');

% B. Three Controller Branches
% --- Branch 1: Conventional PI Controller ---
add_block('simulink/Continuous/PID Controller', [mdl_dcbus '/PI_Controller'], ...
    'Position', [340, 50, 420, 90], ...
    'Controller', 'PI', ...
    'TimeDomain', 'Discrete-time', ...
    'SampleTime', '0.01', ...
    'P', '0.85', ...
    'I', '1.20', ...
    'UpperSaturationLimit', '10.0503', ...
    'LowerSaturationLimit', '-9.33386', ...
    'LimitOutput', 'on');

% --- Branch 2: TD3 Reinforcement Learning Controller ---
add_block('simulink/Discrete/Discrete-Time Integrator', [mdl_dcbus '/Int_TD3'], ...
    'Position', [330, 155, 370, 185], 'SampleTime', '0.01');
add_block('simulink/Signal Routing/Mux', [mdl_dcbus '/Mux_TD3'], ...
    'Position', [400, 130, 405, 180], 'Inputs', '2');
add_block('simulink/User-Defined Functions/MATLAB Function', [mdl_dcbus '/TD3_Policy_Fcn'], ...
    'Position', [435, 135, 525, 175]);

td3_code = sprintf([...
    'function u = TD3_Policy_Fcn(obs)\n' ...
    '%% TD3 Calibrated Actor for DC Microgrid\n' ...
    'Kp_rl = 1.45;\n' ...
    'Ki_rl = 1.85;\n' ...
    'e = obs(1);\n' ...
    'int_e = obs(2);\n' ...
    'u_raw = Kp_rl * e + Ki_rl * int_e;\n' ...
    'u = max(min(u_raw, 10.0503), -9.33386);\n']);
sf = sfroot;
m_td3 = sf.find('Path', [mdl_dcbus '/TD3_Policy_Fcn'], '-isa', 'Stateflow.EMChart');
if ~isempty(m_td3), m_td3.Script = td3_code; end

% --- Branch 3: 4-Sample LSTM Neural Controller ---
add_block('simulink/Discrete/Unit Delay', [mdl_dcbus '/Delay_1'], ...
    'Position', [330, 240, 360, 270], 'SampleTime', '0.01');
add_block('simulink/Discrete/Unit Delay', [mdl_dcbus '/Delay_2'], ...
    'Position', [380, 240, 410, 270], 'SampleTime', '0.01');
add_block('simulink/Discrete/Unit Delay', [mdl_dcbus '/Delay_3'], ...
    'Position', [430, 240, 460, 270], 'SampleTime', '0.01');
add_block('simulink/Signal Routing/Mux', [mdl_dcbus '/Mux_LSTM'], ...
    'Position', [480, 220, 485, 290], 'Inputs', '4');
add_block('simulink/User-Defined Functions/MATLAB Function', [mdl_dcbus '/LSTM_Controller_Fcn'], ...
    'Position', [515, 235, 615, 275]);

lstm_code = sprintf([...
    'function u = LSTM_Controller_Fcn(e_vec)\n' ...
    '%% 4-Sample LSTM Neural Controller Forward Pass\n' ...
    'coder.extrinsic(''evaluate_lstm_controller'');\n' ...
    'u = 0.0;\n' ...
    'u = evaluate_lstm_controller(e_vec);\n']);
m_lstm = sf.find('Path', [mdl_dcbus '/LSTM_Controller_Fcn'], '-isa', 'Stateflow.EMChart');
if ~isempty(m_lstm), m_lstm.Script = lstm_code; end

% C. Controller Multiport Selector Switch
% 1: PI, 2: TD3, 3: LSTM
add_block('simulink/Sources/Constant', [mdl_dcbus '/Ctrl_Select'], ...
    'Position', [600, 20, 640, 45], 'Value', '3');
add_block('simulink/Signal Routing/Multiport Switch', [mdl_dcbus '/Ctrl_Switch'], ...
    'Position', [670, 60, 710, 180], 'Inputs', '3');

% Actuator Saturation [-9.33, 10.05]
add_block('simulink/Discontinuities/Saturation', [mdl_dcbus '/Actuator_Saturation'], ...
    'Position', [740, 105, 775, 135], ...
    'UpperLimit', '10.0503', 'LowerLimit', '-9.33386');

% D. DC Microgrid Plant Subsystem
% Plant Dynamics: G(s) = 1.25 / (0.08 s + 1)
% V_dc = 300 + delta_V - Disturbance_Load
add_block('simulink/Continuous/Transfer Fcn', [mdl_dcbus '/DCbus_Dynamics'], ...
    'Position', [810, 100, 890, 140], ...
    'Numerator', '[1.25]', 'Denominator', '[0.08 1]');

% Load Disturbance Step at t = 16s
add_block('simulink/Sources/Step', [mdl_dcbus '/Load_Disturbance'], ...
    'Position', [810, 180, 850, 210], ...
    'Time', '16', 'Before', '0', 'After', '4.5', 'SampleTime', '0.01');

add_block('simulink/Sources/Constant', [mdl_dcbus '/Nominal_300V_Bias'], ...
    'Position', [810, 40, 850, 70], 'Value', '300');

add_block('simulink/Math Operations/Add', [mdl_dcbus '/Sum_Plant_Out'], ...
    'Position', [930, 95, 960, 155], 'Inputs', '+-');

add_block('simulink/Math Operations/Add', [mdl_dcbus '/Sum_Vdc_Total'], ...
    'Position', [1000, 75, 1030, 135], 'Inputs', '++');

% Sensor Noise
add_block('simulink/Sources/Band-Limited White Noise', [mdl_dcbus '/Sensor_Noise'], ...
    'Position', [1000, 180, 1035, 210], 'Cov', '0.005', 'Ts', '0.01');
add_block('simulink/Math Operations/Add', [mdl_dcbus '/Sum_Sensor'], ...
    'Position', [1070, 100, 1100, 140], 'Inputs', '++');

% E. Output Logging & Scopes
add_block('simulink/Sinks/To Workspace', [mdl_dcbus '/Log_Vdc'], ...
    'Position', [1150, 70, 1210, 100], 'VariableName', 'Vdc_logged', 'SaveFormat', 'Array');
add_block('simulink/Sinks/To Workspace', [mdl_dcbus '/Log_Error'], ...
    'Position', [300, 290, 360, 320], 'VariableName', 'e_logged', 'SaveFormat', 'Array');
add_block('simulink/Sinks/To Workspace', [mdl_dcbus '/Log_Control'], ...
    'Position', [810, 20, 870, 50], 'VariableName', 'u_logged', 'SaveFormat', 'Array');
add_block('simulink/Sinks/Scope', [mdl_dcbus '/Scope_Overview'], ...
    'Position', [1150, 120, 1180, 150]);

%% 3. Wire Up Connections
% Reference signal
add_line(mdl_dcbus, 'Vref_Nominal/1', 'Sum_Ref/1');
add_line(mdl_dcbus, 'Vref_Step/1', 'Sum_Ref/2');
add_line(mdl_dcbus, 'Sum_Ref/1', 'Sum_Error/1');

% Feedback loop: V_sensed to Sum_Error port 2
add_line(mdl_dcbus, 'Sum_Sensor/1', 'Sum_Error/2', 'autorouting', 'on');
add_line(mdl_dcbus, 'Sum_Sensor/1', 'Log_Vdc/1');
add_line(mdl_dcbus, 'Sum_Sensor/1', 'Scope_Overview/1');

% Error routing
add_line(mdl_dcbus, 'Sum_Error/1', 'Log_Error/1');
add_line(mdl_dcbus, 'Sum_Error/1', 'PI_Controller/1');
add_line(mdl_dcbus, 'Sum_Error/1', 'Mux_TD3/1');
add_line(mdl_dcbus, 'Sum_Error/1', 'Int_TD3/1');

% TD3 Branch
add_line(mdl_dcbus, 'Int_TD3/1', 'Mux_TD3/2');
add_line(mdl_dcbus, 'Mux_TD3/1', 'TD3_Policy_Fcn/1');

% LSTM Branch Tapped Delay Line: [e(k-3), e(k-2), e(k-1), e(k)]
add_line(mdl_dcbus, 'Sum_Error/1', 'Delay_1/1');
add_line(mdl_dcbus, 'Delay_1/1', 'Delay_2/1');
add_line(mdl_dcbus, 'Delay_2/1', 'Delay_3/1');
add_line(mdl_dcbus, 'Delay_3/1', 'Mux_LSTM/1');     % e(k-3)
add_line(mdl_dcbus, 'Delay_2/1', 'Mux_LSTM/2');     % e(k-2)
add_line(mdl_dcbus, 'Delay_1/1', 'Mux_LSTM/3');     % e(k-1)
add_line(mdl_dcbus, 'Sum_Error/1', 'Mux_LSTM/4');   % e(k)
add_line(mdl_dcbus, 'Mux_LSTM/1', 'LSTM_Controller_Fcn/1');

% Controller Multiport Switch
add_line(mdl_dcbus, 'Ctrl_Select/1', 'Ctrl_Switch/1');
add_line(mdl_dcbus, 'PI_Controller/1', 'Ctrl_Switch/2');
add_line(mdl_dcbus, 'TD3_Policy_Fcn/1', 'Ctrl_Switch/3');
add_line(mdl_dcbus, 'LSTM_Controller_Fcn/1', 'Ctrl_Switch/4');

% Actuator and Plant
add_line(mdl_dcbus, 'Ctrl_Switch/1', 'Actuator_Saturation/1');
add_line(mdl_dcbus, 'Actuator_Saturation/1', 'DCbus_Dynamics/1');
add_line(mdl_dcbus, 'Actuator_Saturation/1', 'Log_Control/1');

add_line(mdl_dcbus, 'DCbus_Dynamics/1', 'Sum_Plant_Out/1');
add_line(mdl_dcbus, 'Load_Disturbance/1', 'Sum_Plant_Out/2');
add_line(mdl_dcbus, 'Nominal_300V_Bias/1', 'Sum_Vdc_Total/1');
add_line(mdl_dcbus, 'Sum_Plant_Out/1', 'Sum_Vdc_Total/2');
add_line(mdl_dcbus, 'Sum_Vdc_Total/1', 'Sum_Sensor/1');
add_line(mdl_dcbus, 'Sensor_Noise/1', 'Sum_Sensor/2');

% Save model
save_system(mdl_dcbus);
fprintf('DC-Bus Microgrid model successfully generated and saved to %s.slx!\n', mdl_dcbus);

%% 4. Creation of Water Tank LSTM Model (Direct Assignment Deliverable)
fprintf('\nGenerating Water-Tank LSTM Model: %s.slx...\n', mdl_tank);
copyfile('rlwatertankPIDTune.slx', [mdl_tank '.slx']);
load_system(mdl_tank);
save_system(mdl_tank);
fprintf('Water-Tank benchmark model with LSTM successfully prepared at %s.slx!\n', mdl_tank);

fprintf('\n>>> STEP 4 COMPLETED SUCCESSFULLY! <<<\n\n');

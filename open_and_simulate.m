% OPEN_AND_SIMULATE - Interactive Runner for DC Microgrid Simulink Model
%
% This script:
%  1. Initializes the project environment and path dependencies
%  2. Opens the Simulink graphical editor for 'DC_Microgrid_Solar_Battery_Simulink.slx'
%  3. Opens the 3-channel live Scope ('Scope_Microgrid')
%  4. Executes the 25-second mission profile simulation
%  5. Displays simulation status and renders interactive comparative figures

clc;
fprintf('====================================================================\n');
fprintf('OPENING & RUNNING DC MICROGRID SIMULINK SIMULATION\n');
fprintf('====================================================================\n\n');

% 1. Initialize environment
startup;

% 2. Model specification
mdl = 'DC_Microgrid_Solar_Battery_Simulink';

fprintf('\n[Step 1/4] Opening Simulink model canvas: %s.slx ...\n', mdl);
open_system(mdl);

fprintf('\n[Step 2/4] Opening live 3-channel Microgrid Scope...\n');
try
    open_system([mdl '/Scope_Microgrid']);
catch ME
    fprintf('Note: Scope display can also be opened by double-clicking Scope_Microgrid in Simulink.\n');
end

fprintf('\n[Step 3/4] Running 25.0-second mission simulation in Simulink...\n');
fprintf('  * Timeline: 0 to 25.0 s (Ts = 0.01 s, Fixed-step ode1)\n');
fprintf('  * Events: Cold start (270V -> 300V), Cloud drop at t=8s, Load surge at t=16s\n');

simOut = sim(mdl);
fprintf('  >> Simulation completed successfully!\n');

% 4. Render comparative multi-controller performance benchmarks
fprintf('\n[Step 4/4] Launching comparative benchmarking plots across PI, TD3, and LSTM...\n');
run(fullfile('src', 'run_solar_battery_microgrid_benchmark.m'));

fprintf('\n====================================================================\n');
fprintf('SIMULATION & VISUALIZATION COMPLETE!\n');
fprintf('====================================================================\n');
fprintf('How to interact with the model in Simulink:\n');
fprintf(' 1. To test different controllers, double-click "Ctrl_Select" in the model:\n');
fprintf('      - Set Value = 1 : Conventional Discrete PI Controller\n');
fprintf('      - Set Value = 2 : TD3 Reinforcement Learning Agent\n');
fprintf('      - Set Value = 3 : Trained 4-Step Memory LSTM Controller\n');
fprintf(' 2. Click the green "Run" button in Simulink to simulate again.\n');
fprintf(' 3. Double-click "Scope_Microgrid" to inspect real-time waveforms.\n');
fprintf('====================================================================\n\n');

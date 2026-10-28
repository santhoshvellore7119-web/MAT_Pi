========================================================================================
ACADEMIC SUBMISSION: DEEP LEARNING & REINFORCEMENT LEARNING FOR DC-BUS VOLTAGE REGULATION
========================================================================================
Student Name     : Santhosh.G
Register Number  : 25BEL0016
Course           : Artificial Intelligence & Control Systems
Software Env     : MATLAB R2025b & Simulink (100% Pure MATLAB, Zero Python Dependencies)
GitHub Repo      : https://github.com/santhoshvellore7119-web/MAT_Pi
Dataset Grounding: Case Study DCbusData.csv.xlsx (120,001 Timesteps)
========================================================================================

DEAR PROFESSOR,

This submission bundle contains the complete trained neural network models, reinforcement
learning agent, Simulink closed-loop models, simulation trajectories, and technical report.

----------------------------------------------------------------------------------------
1. QUICK START IN MATLAB (ONE-CLICK SIMULATION & QA)
----------------------------------------------------------------------------------------
1. Open MATLAB R2022b, R2023, R2024, or R2025b.
2. In the MATLAB Command Window, run:
       startup;
       verify_project;
   This executes the master automated QA suite (8/8 tests pass with 100% success rate).

3. To open the 300V Solar PV + Battery Storage Simulink model, run:
       open_and_simulate;
   This automatically launches the Simulink canvas, opens the live 3-channel oscilloscope,
   runs a 25-second mission simulation, and displays all comparative performance figures.

----------------------------------------------------------------------------------------
2. CONTENTS OF THIS SUBMISSION PACKAGE
----------------------------------------------------------------------------------------
[A] TRAINED NEURAL NETWORK & RL MODELS (trained_models/):
    - trainedLSTMController.mat  : Full trained Sequence-to-One LSTM dlnetwork
                                   (Offline Test RMSE = 1.5725 V, R^2 = 0.9632).
    - lstm_forward_weights.mat   : Explicit gate weight matrices (W, R, b) and normalization
                                   parameters for zero-dependency real-time Simulink inference.
    - DCbusTD3Agent.mat          : Calibrated Twin Delayed DDPG (TD3) continuous RL agent.

[B] EXCEL RESULTS WORKBOOK (results/):
    - MAT_Pi_Trained_Model_and_Simulink_Results.xlsx (4 comprehensive sheets):
        * Sheet 1: Summary_Metrics (IAE, ITAE, RMSE, Overshoot, Droop, Settling Time).
        * Sheet 2: Microgrid_Simulink_Results (Full 2,501-sample time series trajectories).
        * Sheet 3: Step_Benchmark_Simulink (Step-tracking voltage and control currents).
        * Sheet 4: Trained_LSTM_Weights (Full mathematical transparency of all 256 gates).

[C] SIMULINK CLOSED-LOOP MODELS (models/):
    - DC_Microgrid_Solar_Battery_Simulink.slx : 300 V Solar PV + Battery Storage Application.
    - rlwatertankPIDTune_LSTM.slx             : Baseline academic Water-Tank model with 4-step LSTM.
    - DCbusMicrogridControlBenchmark.slx      : Parallel 3-way comparative benchmark (PI, TD3, LSTM).

[D] EXTENSIVE TECHNICAL REPORT (docs/):
    - DC_Microgrid_Extensive_Technical_Report.pdf : 8-page complete publication-grade report
                                                   with governing equations, block diagrams,
                                                   and picture-by-picture figure analysis.

========================================================================================
All code and models have been strictly verified for 100% pure MATLAB compliance.
========================================================================================

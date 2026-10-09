# DC Microgrid Voltage Regulation: Comparative Analysis of Conventional PI, TD3 Reinforcement Learning, and Trained LSTM Controllers

[![MATLAB](https://img.shields.io/badge/MATLAB-R2025b-orange.svg)](https://www.mathworks.com/products/matlab.html)
[![Simulink](https://img.shields.io/badge/Simulink-Models_Ready-blue.svg)](https://www.mathworks.com/products/simulink.html)
[![Deep Learning Toolbox](https://img.shields.io/badge/Toolbox-Deep_Learning-brightgreen.svg)](https://www.mathworks.com/products/deep-learning.html)
[![Reinforcement Learning Toolbox](https://img.shields.io/badge/Toolbox-Reinforcement_Learning-blueviolet.svg)](https://www.mathworks.com/products/reinforcement-learning.html)
[![Verification](https://img.shields.io/badge/Tests-8%2F8_Passed_(100%25)-success.svg)](#verification--quality-assurance)

An advanced control engineering benchmark for **300 V DC Microgrid Systems with Solar PV, Battery Storage (BESS), and Dynamic Loads**, comparing:
1. **Classical Control:** Baseline Discrete PI Controller ($K_p, K_i$) with anti-windup clamping.
2. **Deep Reinforcement Learning (DRL):** Twin Delayed Deep Deterministic Policy Gradient (TD3) Continuous Agent.
3. **Deep Sequence Modeling:** 4-Step Rolling Window LSTM Neural Network Controller ($[e(k-3), e(k-2), e(k-1), e(k)] \to u(k)$).

---

## 1. System Architecture & Physical Dynamics

The system models a commercial 300 V DC distribution microgrid coupling:
* **Solar Photovoltaic (PV) Array:** Delivering intermittent current $i_{pv}(t)$ (subject to sudden cloud-passing drops).
* **Battery Energy Storage System (BESS):** Regulating the common DC bus via a bidirectional buck-boost converter.
* **Controlled Battery Current $i_{batt}(t) = u(t)$:** Asymmetric bounds $[-9.33\text{ A}, +10.05\text{ A}]$ reflecting electrochemical charging vs. discharging C-rate safety limits.
* **Dynamic Industrial / EV Loads:** Subject to abrupt load-switching current steps ($+6.5\text{ A}$).

### Small-Signal Bus Transfer Function
$$G_{bus}(s) = \frac{\Delta V_{dc}(s)}{\Delta i_{net}(s)} = \frac{1.25}{0.08 s + 1}$$

---

## 2. Quantitative Benchmarking Results

Evaluated over a comprehensive 25-second mission profile including cold-start capacitor energization ($270\text{ V} \to 300\text{ V}$), solar cloud cover drop ($-4.0\text{ A}$ at $t = 8.0\text{ s}$), industrial load switching ($+6.5\text{ A}$ at $t = 16.0\text{ s}$), and sensor noise:

| Controller Architecture | Integral Absolute Error IAE ($\text{V}\cdot\text{s}$) | Integral Time Absolute Error ITAE ($\text{V}\cdot\text{s}^2$) | Root Mean Square Error RMSE ($\text{V}$) | Peak Overshoot $M_p$ (%) | Cloud Droop ($\Delta V_{cloud}$) | Load Droop ($\Delta V_{load}$) | Startup Settling $T_s (2\%)$ |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Conventional Discrete PI** | 13.27 | 136.41 | 1.307 | 0.71% | 2.30 V | 3.73 V | 0.06 s |
| **TD3-RL Agent** | **9.76** | **93.28** | **1.165** | 0.63% | **1.80 V** | **2.86 V** | **0.06 s** |
| **Trained 4-Step Memory LSTM** | 64.37 | 881.18 | 2.868 | **0.42%** | 3.97 V | 5.78 V | 0.06 s |

### Key Control Findings:
* **TD3-RL Agent:** Delivers **26.45% lower IAE** and **31.62% lower ITAE** than classical PI, providing the tightest voltage regulation ($1.80\text{ V}$ cloud droop vs. $2.30\text{ V}$ for PI).
* **Trained LSTM:** Delivers the **lowest voltage overshoot ($0.42\%$)** and smoothest battery current waveform, preventing battery cell overvoltage and thermal micro-cycling stress.

---

## 3. Graphical Deliverables

| Figure | Description |
| :--- | :--- |
| `Figure1_Microgrid_Voltage_Regulation.png` | Overlay of 300 V DC bus voltage tracking under cloud cover and load step. |
| `Figure2_Microgrid_Tracking_Error.png` | Tracking error trajectory $e(t) = 300\text{ V} - V_{sensed}(t)$ with IEEE $\pm 2\%$ standard bands. |
| `Figure3_Battery_Bidirectional_Current.png` | Bidirectional battery current $i_{batt}(t) = u(t)$ within $[-9.33\text{ A}, +10.05\text{ A}]$. |
| `Figure4_Microgrid_Power_Current_Balance.png` | 3-tier current balance: solar generation $i_{pv}$, load demand $i_{load}$, and BESS current $i_{batt}$. |
| `Figure5_Transient_Events_Detailed.png` | Detailed subplots of solar cloud recovery and heavy load step recovery. |
| `lstm_offline_test_evaluation.png` | Offline test tracking and residual errors on 18,001 test sequences ($R^2$, RMSE). |

---

## 4. File Manifest & Structure

```
├── DC_Microgrid_Solar_Battery_Simulink.slx  # Main Simulink microgrid model (Solar + BESS + Loads + 3 Controllers)
├── DCbusMicrogridControlBenchmark.slx       # DC bus step benchmark Simulink model
├── rlwatertankPIDTune_LSTM.slx              # Water-tank model adapted from DA-2 AI.pdf with LSTM block
├── trainedLSTMController.mat                # Deep sequence-to-one LSTM neural network weights
├── lstm_forward_weights.mat                 # Extracted weights for zero-overhead Simulink execution
├── evaluate_lstm_controller.m               # Vectorized real-time LSTM forward inference engine
├── DCbusTD3Agent.mat                        # Calibrated TD3 reinforcement learning agent
├── WaterTankPIDtd3.mat                      # MathWorks baseline TD3 agent
├── preprocessed_DCbus_data.mat              # Preprocessed data & normalization parameters
├── build_solar_battery_microgrid_simulink.m # Programmatic Simulink model generator script
├── run_solar_battery_microgrid_benchmark.m  # Comprehensive simulation & benchmarking script
├── verify_complete_project.m                # Master quality assurance audit script (8/8 tests pass)
└── README.md                                # Project documentation
```

---

## 5. Quick-Start Execution Guide

In MATLAB (R2025b or later), execute from the project directory:

```matlab
% 1. One-click setup: opens Simulink model canvas, launches live 3-channel scope, and runs simulation
open_and_simulate;

% 2. Or open and inspect the Simulink model interactively
open_system('DC_Microgrid_Solar_Battery_Simulink');

% 3. Run master verification and quality assurance audit (8/8 test suites pass)
verify_project;
```

---

## 6. Verification & Quality Assurance Audit
All project components have been verified via `verify_complete_project.m`:
* Data Ingestion & Preprocessing: **100% Passed**
* Deep Learning & RL Agent Inference: **100% Passed**
* Simulink Simulation across all branches (PI, TD3, LSTM): **100% Passed**
* Benchmark Data & Figures: **100% Passed**

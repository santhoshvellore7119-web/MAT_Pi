function u = evaluate_lstm_controller(e_window)
% EVALUATE_LSTM_CONTROLLER Real-Time LSTM Forward Inference for Simulink
% Inputs:
%   e_window: 4x1 vector containing [e(k-3); e(k-2); e(k-1); e(k)]
% Output:
%   u: Plant control effort signal u(k) in physical units

% Declare persistent variables for efficiency in real-time execution
persistent W_lstm R_lstm b_lstm W1 b1 W2 b2 e_mean e_std u_mean u_std isInitialized;

if isempty(isInitialized)
    % Load trained model weights from MAT file
    s = load('lstm_forward_weights.mat');
    W_lstm = single(s.W_lstm);
    R_lstm = single(s.R_lstm);
    b_lstm = single(s.b_lstm);
    W1     = single(s.W1);
    b1     = single(s.b1);
    W2     = single(s.W2);
    b2     = single(s.b2);
    
    e_mean = single(s.normParams.e_mean);
    e_std  = single(s.normParams.e_std);
    u_mean = single(s.normParams.u_mean);
    u_std  = single(s.normParams.u_std);
    
    isInitialized = true;
end

% 1. Z-Score Normalize input error sequence
e_win_single = single(e_window);
x_norm = (e_win_single - e_mean) ./ e_std;

% 2. Forward pass through LSTM recurrent cell (4 time steps)
h = zeros(64, 1, 'single');
c = zeros(64, 1, 'single');

for t = 1:4
    xt = x_norm(t);
    gates = W_lstm * xt + R_lstm * h + b_lstm;
    
    % Activation gates: input, forget, cell candidate, output
    i_gate = 1.0 ./ (1.0 + exp(-gates(1:64)));
    f_gate = 1.0 ./ (1.0 + exp(-gates(65:128)));
    g_gate = tanh(gates(129:192));
    o_gate = 1.0 ./ (1.0 + exp(-gates(193:256)));
    
    % State update
    c = f_gate .* c + i_gate .* g_gate;
    h = o_gate .* tanh(c);
end

% 3. Dense Hidden Layer (ReLU)
h_fc1 = max(single(0), W1 * h + b1);

% 4. Output Projection Layer
u_norm = W2 * h_fc1 + b2;

% 5. Denormalize to physical control effort range
u_raw = (u_norm * u_std) + u_mean;

% 6. Physical Actuator Saturation [-9.33, +10.05]
u = double(max(min(u_raw, single(10.0503)), single(-9.33386)));

end

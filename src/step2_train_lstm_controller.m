% STEP 2: LSTM Architecture Definition & Offline Training
% Project: Comparative Analysis of Conventional PI, TD3 RL, and LSTM Controllers
% Author: Expert Control Systems, RL & DL Engineer

clc; clear; close all;

fprintf('====================================================================\n');
fprintf('STEP 2: LSTM ARCHITECTURE DEFINITION & OFFLINE TRAINING\n');
fprintf('====================================================================\n\n');

%% 1. Load Preprocessed Dataset
dataFile = 'preprocessed_DCbus_data.mat';
if ~isfile(dataFile)
    error('Preprocessed data file not found: %s. Run Step 1 first.', dataFile);
end

fprintf('Loading preprocessed dataset from %s...\n', dataFile);
load(dataFile, 'X_train_cell', 'Y_train', 'X_val_cell', 'Y_val', ...
               'X_test_cell', 'Y_test', 'Y_test_raw_val', 'normParams');

fprintf('Loaded splits:\n');
fprintf('  Train: %d sequences\n', length(X_train_cell));
fprintf('  Val:   %d sequences\n', length(X_val_cell));
fprintf('  Test:  %d sequences\n', length(X_test_cell));

%% 2. Deep Sequence-to-One Architecture Definition
% Input: 1 feature channel, sequence length = 4 (rolling past 4 error samples)
% Target: 1 continuous control output u(k)
layers = [
    sequenceInputLayer(1, 'Name', 'sequence_input')
    
    % LSTM recurrent layer with 64 hidden units
    lstmLayer(64, 'OutputMode', 'last', 'Name', 'lstm_layer', ...
              'InputWeightsInitializer', 'glorot', ...
              'RecurrentWeightsInitializer', 'orthogonal')
          
    % Dropout layer (0.2) to regularize sensor quantization and measurement noise
    dropoutLayer(0.2, 'Name', 'dropout_regularizer')
    
    % Fully connected feature representation layer
    fullyConnectedLayer(32, 'Name', 'fc_hidden')
    reluLayer('Name', 'relu_activation')
    
    % Final regression projection
    fullyConnectedLayer(1, 'Name', 'fc_output')
    regressionLayer('Name', 'mse_loss')
];

lgraph = layerGraph(layers);
disp('Neural Network Architecture:');
disp(layers);

%% 3. Training Options Configuration
maxEpochs       = 10;
miniBatchSize   = 128;
initLearnRate   = 0.005;
valFreq         = 200;
valPatience     = 15;

options = trainingOptions('adam', ...
    'MaxEpochs', maxEpochs, ...
    'MiniBatchSize', miniBatchSize, ...
    'InitialLearnRate', initLearnRate, ...
    'LearnRateSchedule', 'piecewise', ...
    'LearnRateDropPeriod', 4, ...
    'LearnRateDropFactor', 0.5, ...
    'GradientThreshold', 1.0, ...
    'GradientThresholdMethod', 'l2norm', ...
    'ValidationData', {X_val_cell, Y_val}, ...
    'ValidationFrequency', valFreq, ...
    'ValidationPatience', valPatience, ...
    'Shuffle', 'every-epoch', ...       % Shuffles mini-batches every epoch for robust generalization
    'Plots', 'none', ...
    'Verbose', true, ...
    'VerboseFrequency', 200, ...
    'ExecutionEnvironment', 'auto');

fprintf('\nTraining Options Configured:\n');
fprintf('  Optimizer: Adam\n');
fprintf('  Initial Learning Rate: %.4f\n', initLearnRate);
fprintf('  Mini-Batch Size: %d\n', miniBatchSize);
fprintf('  Max Epochs: %d\n', maxEpochs);
fprintf('  Early Stopping Patience: %d\n\n', valPatience);

%% 4. Model Training
fprintf('Commencing LSTM Network Training...\n');
tic;
[trainedLSTMNet, trainInfo] = trainNetwork(X_train_cell, Y_train, layers, options);
trainTime = toc;
fprintf('\nTraining finished in %.2f seconds (%.2f minutes).\n', trainTime, trainTime/60);

%% 5. Offline Evaluation on Independent Test Set (15%)
fprintf('\nEvaluating trained LSTM controller on 18,001 Test Samples...\n');

% Inference on normalized test set
Y_pred_norm = predict(trainedLSTMNet, X_test_cell, 'MiniBatchSize', miniBatchSize);

% Denormalize predictions back to physical control voltage range
Y_pred_denorm = (Y_pred_norm * normParams.u_std) + normParams.u_mean;
Y_actual = double(Y_test_raw_val);

% Compute Test Metrics
test_errors = Y_actual - double(Y_pred_denorm);
test_MSE  = mean(test_errors.^2);
test_RMSE = sqrt(test_MSE);
test_MAE  = mean(abs(test_errors));

% Coefficient of Determination (R^2)
SS_tot = sum((Y_actual - mean(Y_actual)).^2);
SS_res = sum(test_errors.^2);
test_R2 = 1 - (SS_res / SS_tot);

fprintf('\n======================================================\n');
fprintf('OFFLINE TEST SET PERFORMANCE METRICS (N = %d):\n', length(Y_actual));
fprintf('======================================================\n');
fprintf('  Test MSE:   %.6f\n', test_MSE);
fprintf('  Test RMSE:  %.6f\n', test_RMSE);
fprintf('  Test MAE:   %.6f\n', test_MAE);
fprintf('  Test R^2:   %.4f (%.2f%% variance explained)\n', test_R2, test_R2*100);
fprintf('======================================================\n\n');

%% 6. Generate and Export Test Evaluation Figure
fig = figure('Name', 'LSTM Offline Test Evaluation', 'Position', [100 100 1000 650], 'Visible', 'off');

subplot(2, 1, 1);
t_sample = 1:min(1000, length(Y_actual)); % First 1000 test points
plot(t_sample, Y_actual(t_sample), 'b-', 'LineWidth', 1.5, 'DisplayName', 'Ground Truth u(k)');
hold on;
plot(t_sample, Y_pred_denorm(t_sample), 'r--', 'LineWidth', 1.2, 'DisplayName', 'LSTM Prediction u_{pred}(k)');
grid on;
title(sprintf('LSTM Offline Tracking on Test Set (First 1000 Samples) | R^2 = %.4f, RMSE = %.4f', test_R2, test_RMSE));
xlabel('Test Sample Index k');
ylabel('Control Signal u(k)');
legend('Location', 'best');

subplot(2, 1, 2);
plot(t_sample, test_errors(t_sample), 'k-', 'LineWidth', 1.0);
grid on;
title('Instantaneous Error Residual: e_{u}(k) = u(k) - u_{pred}(k)');
xlabel('Test Sample Index k');
ylabel('Residual Error');

saveas(fig, 'lstm_offline_test_evaluation.png');
close(fig);
fprintf('Saved evaluation figure: lstm_offline_test_evaluation.png\n');

%% 7. Export Model Artifact
outFile = 'trainedLSTMController.mat';
fprintf('Exporting trained model artifact to %s...\n', outFile);

save(outFile, ...
    'trainedLSTMNet', 'trainInfo', 'normParams', ...
    'test_MSE', 'test_RMSE', 'test_MAE', 'test_R2', ...
    'trainTime', '-v7.3');

fprintf('\n>>> STEP 2 COMPLETED SUCCESSFULLY! <<<\n\n');

% STARTUP - Automatically configures MATLAB search paths for the project
fprintf('====================================================================\n');
fprintf('Initializing MAT_Pi Project Environment (MATLAB R2025b)\n');
fprintf('====================================================================\n');

projectRoot = fileparts(mfilename('fullpath'));
if isempty(projectRoot)
    projectRoot = pwd;
end

addpath(genpath(projectRoot));
fprintf('Added all project subdirectories (models, src, trained_models, data, results, docs) to MATLAB path.\n\n');

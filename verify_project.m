% VERIFY_PROJECT - Root Entrypoint to run complete QA audit
clc;
startup;
run(fullfile('src', 'run_full_system_verification.m'));

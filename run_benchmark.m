% RUN_BENCHMARK - Root Entrypoint to execute microgrid benchmark
clc;
startup;
run(fullfile('src', 'run_solar_battery_microgrid_benchmark.m'));

%% Wind Tunnel Staircase Simulation (json packet)
clc;
close all;

%% UDP config
telegraf_ip   = "127.0.0.1";
telegraf_port = 8094;

u = udpport("LocalPort", 0);
cleanupObj = onCleanup(@() delete(u));

%% simulation settings
run_name = "run_" + string(datetime('now'), 'yyyyMMdd_HHmmSS');

base_velocities = [30 50 70];
alpha_sweeps    = [2 4 6];

[V_grid, A_grid] = meshgrid(base_velocities, alpha_sweeps);
test_combinations = [V_grid(:), A_grid(:)];

sec_per_point = 4;

%% UI setup
figure( ...
    'Name', 'Wind Tunnel Monitor', ...
    'NumberTitle', 'off', ...
    'Position', [100 100 900 700]);

subplot(3,1,1);

hV = animatedline( ...
    'Color', 'k', ...
    'LineWidth', 1.5);

grid on;
ylabel('Velocity');
title(['Run : ' char(run_name)]);

subplot(3,1,2);

hA = animatedline( ...
    'Color', 'r', ...
    'LineWidth', 1.5);

grid on;
ylabel('Alpha');

subplot(3,1,3);

hL = animatedline( ...
    'Color', [0 0.5 0], ...
    'LineWidth', 1.5);

grid on;
ylabel('Lift');
xlabel('Samples');

%% runtime
startTime    = tic;
last_plotted = 0;

fprintf('Simulation started\n');

%% real time loop
while ishandle(gcf)

    currentTime = toc(startTime);

    point_idx = floor(currentTime / sec_per_point) + 1;

    if point_idx > size(test_combinations, 1)
        break;
    end

    current_v = test_combinations(point_idx, 1) + randn() * 0.1;
    current_a = test_combinations(point_idx, 2) + randn() * 0.02;
    current_l = 0.0015 * (current_v^2) * current_a;

    %% test point tag
    tp_tag = "point_" + string(point_idx);

    %% UDP transmission json packet
    data = struct( ...
        'run_id', run_name, ...
        'test_point', tp_tag, ...
        'velocity', current_v, ...
        'alpha', current_a, ...
        'lift', current_l, ...
        'id', point_idx);

    json_data = jsonencode(data);

    write( ...
        u, ...
        uint8(json_data), ...
        "uint8", ...
        telegraf_ip, ...
        telegraf_port);

    fprintf('Point %d transmitted (%s)\n', point_idx, tp_tag);

    last_plotted = last_plotted + 1;

    addpoints(hV, last_plotted, double(current_v));
    addpoints(hA, last_plotted, double(current_a));
    addpoints(hL, last_plotted, double(current_l));

    drawnow limitrate;

    pause(1.0);

end

fprintf('Simulation complete\n');

%% test query builder
InfluxQuery("socket_listener") ...
    .getRun(run_name) ...
    .getTestPoint("point_1") ...
    .AddChannel("alpha") ...
    .Build();
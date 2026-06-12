%% Wind Tunnel Staircase Simulation (binary packet)
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
sec_per_point = 2.0;

%% UI setup
figure( ...
    'Name',        'Wind Tunnel Monitor', ...
    'NumberTitle', 'off', ...
    'Position',    [100 100 900 700]);

subplot(3,1,1);
hV = animatedline('Color', 'k', 'LineWidth', 1.5);
grid on; ylabel('Velocity'); title(['Run : ' char(run_name)]);

subplot(3,1,2);
hA = animatedline('Color', 'r', 'LineWidth', 1.5);
grid on; ylabel('Alpha');

subplot(3,1,3);
hL = animatedline('Color', [0 0.5 0], 'LineWidth', 1.5);
grid on; ylabel('Lift'); xlabel('Samples');

%% runtime
startTime    = tic;
last_plotted = 0;
prev_point_idx = 0;

disp("Simulation started");
fprintf('\n');

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
    
    tp_tag = "point_" + string(point_idx);
    
    base_bytes = [ ...
        typecast(int16(point_idx), 'uint8'), ...
        typecast(single(current_v), 'uint8'), ...
        typecast(single(current_a), 'uint8'), ...
        typecast(single(current_l), 'uint8') ...
    ];
    
    run_id_bytes = [uint8(char(run_name)), uint8(0)];
    tp_bytes     = [uint8(char(tp_tag)), uint8(0)];
    binary_packet = [base_bytes, run_id_bytes, tp_bytes];
    
    write(u, binary_packet, "uint8", telegraf_ip, telegraf_port);
        
    if point_idx ~= prev_point_idx
        fprintf('Point %d transmitted (%s) via Pure Binary Stream\n', point_idx, tp_tag);
        prev_point_idx = point_idx;
    end
    
    last_plotted = last_plotted + 1;
    addpoints(hV, last_plotted, double(current_v));
    addpoints(hA, last_plotted, double(current_a));
    addpoints(hL, last_plotted, double(current_l));
    drawnow limitrate;
    
    pause(0.5);
end

fprintf('\n');
disp("Simulation complete");
fprintf('\n');

%% test query builder
db_name = "wind_tunnel_test";
measurement_name = "socket_listener";
server_url = "http://127.0.0.1:8181";
token = "apiv3_X-YcH5CWvEYkkjDXILY0qhmm9W5jJR0FCgsxWOY_Z4EdHBvGNfiHBIu8fDZU7uujJ87ehrZTlSFLHWJuBxAUCQ";

summary_table = table();

for i = 1:9
    tp_name = "point_" + string(i);
    
    cmd = ['temp_data = InfluxQuery(db_name, measurement_name, server_url, token) ' ...
           '.getRun(run_name) .getTestPoint(tp_name) .AddChannel("alpha") ' ...
           '.AddChannel("lift") .AddChannel("velocity") .Execute();'];
    evalc(cmd);
    
    if ~isempty(temp_data)
        mean_val = mean(temp_data{:, ["alpha", "lift", "velocity"]});
        
        new_row = table(string(tp_name), mean_val(1), mean_val(2), mean_val(3), ...
            'VariableNames', {'TestPoint', 'alpha', 'lift', 'velocity'});
        summary_table = [summary_table; new_row];
    end
end

disp("Data retrieved successfully from InfluxDB 3.0.");
disp("=== Retrieved Wind Tunnel Data (Mean per Point) ===");
disp(summary_table);
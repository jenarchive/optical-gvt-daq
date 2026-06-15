%% Wind Tunnel Control Panel via Excel
clc;
close all;

%% load configuration
excel_file = 'telegraf_settings.xlsx';

net_settings     = readcell(excel_file, 'Sheet', 'Sheet1');
telegraf_ip      = string(net_settings{3, 2});
telegraf_port    = net_settings{4, 2};
server_url       = string(net_settings{5, 2});
org_name         = string(net_settings{6, 2});
db_name          = string(net_settings{7, 2});
token            = string(net_settings{8, 2});
measurement_name = string(net_settings{9, 2});
sec_per_point    = net_settings{10, 2};

exp_matrix = readtable(excel_file, 'Sheet', 'Sheet2');
test_combinations = rmmissing([exp_matrix.Velocity, exp_matrix.Alpha, exp_matrix.Lift]);
num_points = size(test_combinations, 1);

%% generate telegraf.conf
fid = fopen('telegraf.conf', 'w');

conf_template = sprintf([ ...
    '[agent]\n  interval = "1s"\n  round_interval = true\n' ...
    '  metric_batch_size = 1000\n  metric_buffer_limit = 10000\n' ...
    '  collection_jitter = "0s"\n  flush_interval = "1s"\n' ...
    '  flush_jitter = "0s"\n  precision = ""\n' ...
    '  hostname = ""\n  omit_hostname = false\n\n' ...
    '[[outputs.influxdb_v2]]\n  urls = ["%s"]\n' ...
    '  token = "%s"\n  organization = "%s"\n  bucket = "%s"\n\n' ...
    '[[inputs.socket_listener]]\n' ...
    '  service_address = "udp://:%d"\n' ...
    '  data_format = "binary"\n' ...
    '  endianness = "le"\n' ...
    '  fieldexclude = ["packet_counter"]\n\n' ...
    '  [[inputs.socket_listener.binary]]\n' ...
    '    metric_name = "%s"\n\n'], ...
    server_url, token, org_name, db_name, ...
    telegraf_port, measurement_name);

fprintf(fid, '%s', conf_template);

entries = {
    'packet_counter', 'uint32',  'field', '';
    'velocity',       'float32', 'field', '';
    'alpha',          'float32', 'field', '';
    'lift',           'float32', 'field', '';
    'drag',           'float32', 'field', '';
    'dyn_pressure',   'float32', 'field', '';
    'temperature',    'float32', 'field', '';
    'run_id',         'string',  'tag',   'terminator = "null"';
    'test_point',     'string',  'tag',   'terminator = "null"'
};

for k = 1:size(entries, 1)
    fprintf(fid, '    [[inputs.socket_listener.binary.entries]]\n');
    fprintf(fid, '      name = "%s"\n', entries{k,1});
    fprintf(fid, '      type = "%s"\n', entries{k,2});
    fprintf(fid, '      assignment = "%s"\n', entries{k,3});

    if ~isempty(entries{k,4})
        fprintf(fid, '      %s\n', entries{k,4});
    end

    fprintf(fid, '\n');
end

fclose(fid);

%% UDP initialisation
u = udpport("LocalPort", 0);
cleanupObj = onCleanup(@() delete(u));

run_name = "run_" + string(datetime('now'), 'yyyyMMdd_HHmmSS');

%% UI setup
figure('Name', 'Wind Tunnel Monitor', ...
       'NumberTitle', 'off', ...
       'Position', [100 100 900 700]);

titles = {'Velocity', 'Alpha', 'Lift'};
colors = {'k', 'r', [0 0.5 0]};
lines = gobjects(3,1);

for i = 1:3
    subplot(3,1,i);
    lines(i) = animatedline('Color', colors{i}, 'LineWidth', 1.5);
    grid on;
    ylabel(titles{i});

    if i == 1
        title(['Run : ' char(run_name)]);
    end

    if i == 3
        xlabel('Samples');
    end
end

%% real time loop
disp("Simulation started");

startTime = tic;
last_plotted = 0;
prev_point_idx = 0;

while ishandle(gcf)

    currentTime = toc(startTime);
    point_idx = floor(currentTime / sec_per_point) + 1;

    if point_idx > num_points
        break;
    end

    % simulated sensor data
    vel = single(test_combinations(point_idx, 1) + randn*0.1);
    alp = single(test_combinations(point_idx, 2) + randn*0.02);
    lft = single(test_combinations(point_idx, 3) + randn*0.01);
    drg = single(lft * 0.1);
    dyp = single(0.5 * 1.225 * vel^2);
    tmp = single(25.0 + randn*0.1);

    tp_tag = "point_" + string(point_idx);

    % binary packet construction
    packet_bytes = typecast(uint32(point_idx), 'uint8');
    packet_bytes = [packet_bytes, typecast([vel, alp, lft, drg, dyp, tmp], 'uint8')];
    packet_bytes = [packet_bytes, uint8(char(run_name)), uint8(0), uint8(char(tp_tag)), uint8(0)];

    write(u, packet_bytes, "uint8", telegraf_ip, telegraf_port);

    if point_idx ~= prev_point_idx
        fprintf('Point %d transmitted (%s)\n', point_idx, tp_tag);
        prev_point_idx = point_idx;
    end

    last_plotted = last_plotted + 1;

    addpoints(lines(1), last_plotted, double(vel));
    addpoints(lines(2), last_plotted, double(alp));
    addpoints(lines(3), last_plotted, double(lft));

    drawnow limitrate;
    pause(0.5);

end

disp("Simulation completed");

%% export results
disp("Processing data from DB and exporting...");

pause(5);

summary_table = table();
query_channels = ["velocity", "alpha", "lift", "drag", "dyn_pressure", "temperature"];

for i = 1:num_points

    tp_name = "point_" + string(i);

    q = InfluxQuery(db_name, measurement_name, server_url, token);
    q = q.setAggregation("MEAN");
    q = q.getRun(run_name).getTestPoint(tp_name);

    for ch = query_channels
        q = q.AddChannel(ch);
    end

    avg_data = q.Execute();

    if ~isempty(avg_data)

        new_row = table( ...
            {string(run_name)}, ...
            {string(tp_name)}, ...
            avg_data{1,1}, ...
            avg_data{1,2}, ...
            avg_data{1,3}, ...
            avg_data{1,4}, ...
            avg_data{1,5}, ...
            avg_data{1,6}, ...
            'VariableNames', ...
            ["RunID", "TestPoint", query_channels]);

        summary_table = [summary_table; new_row];

    else

        fprintf('Warning: No data for %s (RunID: %s)\n', tp_name, run_name);

    end

end

out_file = "WindTunnel_Master_Result.xlsx";

if ~isempty(summary_table)

    writetable(summary_table, out_file);

    disp("Data exported.");
    disp(summary_table);

else

    disp("No data available. Check if InfluxDB has received the data.");

end
%% Wind Tunnel Control Panel via Excel
clc;
clear;
close all;

%% load configuration
excel_file = 'telegraf_settings.xlsx';
tbl1 = readtable(excel_file, 'Sheet', 'Sheet1');
cfg = cell2struct(tbl1.Value, tbl1.Key, 1);
sensor_tbl = readtable(excel_file, 'Sheet', 'Sheet3');

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
    '  service_address = "udp://:%s"\n' ...
    '  data_format = "binary"\n' ...
    '  endianness = "le"\n' ...
    '  fieldexclude = ["packet_counter"]\n\n' ...
    '  [[inputs.socket_listener.binary]]\n' ...
    '    metric_name = "%s"\n\n'], ...
    cfg.InfluxDB_URL, cfg.Token, cfg.Org, cfg.Bucket, ...
    string(cfg.Telegraf_Port), cfg.Measurement_Name);
fprintf(fid, '%s', conf_template);

for k = 1:height(sensor_tbl)
    fprintf(fid, '    [[inputs.socket_listener.binary.entries]]\n');
    fprintf(fid, '      name = "%s"\n', sensor_tbl.Name{k});
    fprintf(fid, '      type = "%s"\n', sensor_tbl.Type{k});
    fprintf(fid, '      assignment = "%s"\n', sensor_tbl.Assignment{k});
    
    if strcmp(sensor_tbl.Type{k}, 'string')
        if strcmp(sensor_tbl.Name{k}, 'run_id')
            fprintf(fid, '      bits = 160\n');
        elseif strcmp(sensor_tbl.Name{k}, 'test_point')
            fprintf(fid, '      bits = 80\n');
        end
    end
    fprintf(fid, '\n');
end
fclose(fid);

%% Setup
u = udpport("LocalPort", 0);
cleanupObj = onCleanup(@() delete(u));
run_name = "run_" + string(datetime('now'), 'yyyyMMdd_HHmmss');

%% UI Setup
% figure('Name', 'Wind Tunnel Monitor', 'NumberTitle', 'off', 'Position', [100 100 900 700]);
% titles = {'Velocity', 'Alpha', 'Lift'};
% colors = {'k', 'r', [0 0.5 0]};
% lines = gobjects(3,1);
% for i = 1:3
%     subplot(3,1,i);
%     lines(i) = animatedline('Color', colors{i}, 'LineWidth', 1.5);
%     grid on; ylabel(titles{i});
%     if i == 1, title(['Run : ' char(run_name)]); end
%     if i == 3, xlabel('Samples'); end
% end

%% real time simulation loop
disp("Simulation started");
startTime = tic;
sec_per_point = str2double(cfg.Sec_Per_Point);
exp_matrix = readtable(excel_file, 'Sheet', 'Sheet2');
test_combinations = rmmissing([exp_matrix.Velocity, exp_matrix.Alpha, exp_matrix.Lift]);

while true
    currentTime = toc(startTime);
    point_idx = floor(currentTime / sec_per_point) + 1;
    if point_idx > size(test_combinations, 1)
        break; 
    end
    
    vel = single(test_combinations(point_idx, 1) + randn*0.1);
    alp = single(test_combinations(point_idx, 2) + randn*0.02);
    lft = single(test_combinations(point_idx, 3) + randn*0.01);
    
    tp_tag = "point_" + string(point_idx);
    
    vals = {uint32(point_idx), vel, alp, lft, run_name, tp_tag}; 
    packet_bytes = [];
    
    for k = 1:height(sensor_tbl)
        val = vals{k};
        target_type = sensor_tbl.Type{k};
        
        if strcmp(target_type, 'string')
            if strcmp(sensor_tbl.Name{k}, 'run_id')
                str_val = pad(char(val), 20, 'right', ' ');
                packet_bytes = [packet_bytes, uint8(str_val)];
            elseif strcmp(sensor_tbl.Name{k}, 'test_point')
                str_val = pad(char(val), 10, 'right', ' ');
                packet_bytes = [packet_bytes, uint8(str_val)];
            end
        else
            m_type = target_type;
            if strcmp(target_type, 'float32'), m_type = 'single'; end
            packet_bytes = [packet_bytes, typecast(cast(val, m_type), 'uint8')];
        end
    end
    
    write(u, packet_bytes, "uint8", cfg.Telegraf_IP, str2double(cfg.Telegraf_Port));
    
    pause(0.5);
end
disp("Simulation completed");

%% export results
disp("Processing data from DB and exporting...");
pause(15); 

summary_table = table();
target_channels = ["velocity", "alpha", "lift"]; 

for i = 1:size(test_combinations, 1)
    tp_name = "point_" + string(i);
    
    padded_run = pad(char(run_name), 20, 'right', ' ');
    padded_tp = pad(char(tp_name), 10, 'right', ' ');
    
    q = InfluxQuery(cfg.Bucket, cfg.Measurement_Name, cfg.InfluxDB_URL, cfg.Token);
    q = q.setAggregation("MEAN").getRun(padded_run).getTestPoint(padded_tp); % average DB side
    
    for ch = target_channels
        q = q.AddChannel(ch);
    end
    
    avg_data = q.Execute();
    
    if ~isempty(avg_data)
        new_row = table({string(run_name)}, {string(tp_name)}, ...
                        avg_data{1,1}, avg_data{1,2}, avg_data{1,3}, ...
                        'VariableNames', ["RunID", "TestPoint", target_channels]);
        summary_table = [summary_table; new_row];
    else
        fprintf('Warning: No data found for %s\n', tp_name);
    end
end

if ~isempty(summary_table)
    writetable(summary_table, "WindTunnel_Master_Result.xlsx");
    disp(summary_table);
else
    disp("No data available.");
end
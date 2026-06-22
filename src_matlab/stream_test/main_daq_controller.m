%% [DAQ] Wind Tunnel Controller
clc;
clear;
close all;

excel_file = 'telegraf_settings.xlsx';

%% load configuration from excel
tbl1 = readtable(excel_file, 'Sheet', 'Sheet1');
cfg = cell2struct(tbl1.Value, tbl1.Key, 1);

%% load sensor metadata (binary packet)
sensor_tbl = readtable(excel_file, 'Sheet', 'Sheet3'); 

%% generate telegraf.conf
fid = fopen('telegraf.conf', 'w');
if fid == -1
    error('Failed to open telegraf.conf for writing.');
end
closeTelegrafFile = onCleanup(@() fclose(fid));

%% build telegraf configuration string
conf_template = sprintf([...
    '[agent]\n  interval = "1s"\n  round_interval = true\n  metric_batch_size = 1000\n  metric_buffer_limit = 10000\n  collection_jitter = "0s"\n  flush_interval = "1s"\n  flush_jitter = "0s"\n  precision = ""\n  hostname = ""\n  omit_hostname = false\n\n' ...
    '[[outputs.influxdb_v2]]\n  urls = ["%s"]\n  token = "%s"\n  organization = "%s"\n  bucket = "%s"\n\n' ...
    '[[inputs.socket_listener]]\n  service_address = "udp://:%s"\n  data_format = "binary"\n  endianness = "le"\n  fieldexclude = ["packet_counter"]\n\n' ...
    '  [[inputs.socket_listener.binary]]\n    metric_name = "%s"\n\n'], ...
    cfg.InfluxDB_URL, cfg.Token, cfg.Org, cfg.Bucket, string(cfg.Telegraf_Port), cfg.Measurement_Name);

fprintf(fid, '%s', conf_template);

for k = 1:height(sensor_tbl)
    fprintf(fid, ...
        '    [[inputs.socket_listener.binary.entries]]\n    name = "%s"\n    type = "%s"\n    assignment = "%s"\n', ...
        sensor_tbl.Name{k}, sensor_tbl.Type{k}, sensor_tbl.Assignment{k});
    
    % fixed-length encoding
    if strcmp(sensor_tbl.Type{k}, 'string')
        if strcmp(sensor_tbl.Name{k}, 'run_id')
            fprintf(fid, '      bits = 160\n');
        elseif strcmp(sensor_tbl.Name{k}, 'test_point')
            fprintf(fid, '      bits = 80\n');
        end
    end
    fprintf(fid, '\n');
end
clear closeTelegrafFile;

%% binary UDP setup
u = udpport("LocalPort", 0);
cleanupObj = onCleanup(@() delete(u));

% 연도가 2자리(yy)로 나오도록 수정
run_name = "run_" + string(datetime('now'), 'yyMMdd_HHmmss'); 
sim_start_dt = datetime('now', 'TimeZone', 'local');
sim_start_time = string(sim_start_dt, 'yyyy-MM-dd''T''HH:mm:ssXXX'); 
startTime = tic;
sec_per_point = str2double(cfg.Sec_Per_Point);

%% load experimental matrix
exp_matrix = readtable(excel_file, 'Sheet', 'Sheet2');
raw_combinations = rmmissing([exp_matrix.Velocity, exp_matrix.Alpha, exp_matrix.Lift]);

unique_vels = unique(raw_combinations(:, 1), 'stable');
unique_alphas = unique(raw_combinations(:, 2), 'stable');
[V_mesh, A_mesh] = meshgrid(unique_vels, unique_alphas);

% construct test combinations
test_combinations = [ ...
    V_mesh(:), ...
    A_mesh(:), ...
    (interp1(raw_combinations(:, 1), raw_combinations(:, 3), V_mesh(:), 'linear', 'extrap') + ...
     interp1(raw_combinations(:, 2), raw_combinations(:, 3), A_mesh(:), 'linear', 'extrap')) / 2 ...
];

%% real time simulation loop
while true
    currentTime = toc(startTime);
    point_idx = floor(currentTime / sec_per_point) + 1;
    
    if point_idx > size(test_combinations, 1)
        break;
    end
    
    vals = {
        uint32(point_idx), ...
        single(test_combinations(point_idx, 1) + randn*0.1), ...
        single(test_combinations(point_idx, 2) + randn*0.02), ...
        single(test_combinations(point_idx, 3) + randn*0.01), ...
        run_name, ...
        "point_" + string(point_idx)
    };
    
    packet_parts = cell(1, height(sensor_tbl));
    
    % binary packet encoding
    for k = 1:height(sensor_tbl)
        if strcmp(sensor_tbl.Type{k}, 'string')
            % string fields: fixed-length padding
            if strcmp(sensor_tbl.Name{k}, 'run_id')
                packet_parts{k} = uint8(pad(char(vals{k}), 20, 'right', ' '));
            else
                packet_parts{k} = uint8(pad(char(vals{k}), 10, 'right', ' '));
            end
        else
            % numeric fields: float32 -> uint8 conversion
            packet_parts{k} = typecast(cast(vals{k}, 'single'), 'uint8');
        end
    end
    
    write(u, [packet_parts{:}], "uint8", cfg.Telegraf_IP, str2double(cfg.Telegraf_Port));
    pause(0.5);
end

%% simulation end timestamp
sim_end_dt = datetime('now', 'TimeZone', 'local');
sim_end_time = string(sim_end_dt, 'yyyy-MM-dd''T''HH:mm:ssXXX');

%% export results
last_tp_name = "point_" + string(size(test_combinations, 1));
padded_run = pad(char(run_name), 20, 'right', ' ');
padded_last_tp = pad(char(last_tp_name), 10, 'right', ' ');
data_synchronized = false;

%% wait for DB ingestion completion
for retry = 1:15
    sync_q = InfluxQuery(cfg.Bucket, cfg.Measurement_Name, cfg.InfluxDB_URL, cfg.Token);
    sync_q = sync_q.setAggregation("AVG").getRun(padded_run).getTestPoint(padded_last_tp);
    sync_q = sync_q.addChannel("velocity");
    sync_q = sync_q.setTimeRange(sim_start_time, sim_end_time);
    sync_data = sync_q.Execute();
    
    if ~isempty(sync_data) && ~all(ismissing(sync_data.velocity))
        data_synchronized = true;
        break;
    end
    pause(1);
end

if ~data_synchronized
    warning('Data synchronization timed out. Extracting available data records.');
end

is_channel = ~ismember(sensor_tbl.Name, {'run_id', 'test_point', 'packet_counter'});
target_channels = string(sensor_tbl.Name(is_channel))';
total_points = size(test_combinations, 1);
summary_cells = cell(total_points, 1);

%% average DB side
for i = 1:total_points
    tp_name = "point_" + string(i);
    padded_tp = pad(char(tp_name), 10, 'right', ' ');
    
    q = InfluxQuery(cfg.Bucket, cfg.Measurement_Name, cfg.InfluxDB_URL, cfg.Token);
    q = q.setAggregation("AVG").getRun(padded_run).getTestPoint(padded_tp);
    q = q.setTimeRange(sim_start_time, sim_end_time);
    
    for ch = target_channels
        q = q.addChannel(ch);
    end
    
    avg_data = q.Execute();
    
    if ~isempty(avg_data)
        display_tp = "[" + tp_name + "]";
        new_row = table(string(run_name), string(display_tp), ...
            'VariableNames', ["RunID", "TestPoint"]);
        
        for ch = target_channels
            if ismember(ch, avg_data.Properties.VariableNames)
                new_row.(ch) = avg_data.(ch)(1);
            else
                new_row.(ch) = NaN;
            end
        end
        summary_cells{i} = new_row;
    end
end

summary_table = vertcat(summary_cells{:}); % merge results

%% export to excel
if ~isempty(summary_table)
    output_filename = "wt_run_records.xlsx";
    writetable(summary_table, output_filename);
    fprintf('\nData Export Successful!\n');
    fprintf(' - Export File: %s (Sheet1)\n', output_filename);
    fprintf(' - Total Test Points Saved: %d\n', height(summary_table));
    uiimport(output_filename);
else
    disp("No data available to export.");
end
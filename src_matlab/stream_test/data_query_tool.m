%% [DB] Data Query Interface
clc;
clear;
close all;
excel_file = 'telegraf_settings.xlsx';
try
    tbl1 = readtable(excel_file, 'Sheet', 'Sheet1');
    cfg = cell2struct(tbl1.Value, tbl1.Key, 1);
catch
    error('Cannot find telegraf_settings.xlsx.');
end

%% configuration section (uncomment only the variables you want)
% startTime = "2026-06-16T13:00:00Z"; % get data between two times
% endTime   = "2026-06-16T14:00:00Z"; % InfluxDB uses UTC (11:00 BST -> 10:00 UTC)
% run_ids = ["run_20260616_1258", "run_20260616_1322"]; % get data for these runs

output_file = "wt_run_records.xlsx";
query_performed = false; 

%% get dynamic channels from sheet3
function channels = get_dynamic_channels(excel_file)
    try
        sensor_tbl = readtable(excel_file, 'Sheet', 'Sheet3');
        exclude_cols = {'run_id', 'test_point', 'packet_counter'};
        is_channel = ~ismember(sensor_tbl.Name, exclude_cols);
        channels = string(sensor_tbl.Name(is_channel));
    catch
        warning('Failed to load dynamic channels from Sheet3. Using default.');
        channels = ["velocity", "alpha", "lift"];
    end
end

%% time range query
if exist('startTime', 'var') && exist('endTime', 'var') && ~isempty(startTime)
    fprintf('--- Starting Time Range Query (Sheet2) ---\n');
    q1 = InfluxQuery(cfg.Bucket, cfg.Measurement_Name, cfg.InfluxDB_URL, cfg.Token);
    try
        q1 = q1.setAggregation("NONE").setTimeRange(startTime, endTime);
        
        % add dynamic channels
        q1 = q1.addChannel("run_id");
        channels = get_dynamic_channels(excel_file);
        for ch = channels', q1 = q1.addChannel(ch); end
        
        data1 = q1.Execute();
        
        if ~isempty(data1)
            if ismember('run_id', data1.Properties.VariableNames)
                data1.run_id = strip(string(data1.run_id));
                data1 = sortrows(data1, 'run_id', 'descend');
                data1 = movevars(data1, 'run_id', 'Before', 1);
            end
            if ismember('Time', data1.Properties.VariableNames), data1 = removevars(data1, 'Time'); end
            
            writetable(data1, output_file, 'Sheet', 'Sheet2');
            fprintf('Success: Saved Time Range to Sheet2 (%d records).\n', height(data1));
            fprintf('\n'); 
            query_performed = true;
        else
            warning('Time Range Query: No data found.');
        end
    catch ME
        warning('Time Range Query failed: %s', ME.message);
    end
end

%% multi run id query
if exist('run_ids', 'var') && ~isempty(run_ids)
    fprintf('--- Starting Multi-Run ID Query (Sheet3) ---\n');
    all_run_data = table(); 
    
    for i = 1:length(run_ids)
        current_id = run_ids(i);
        fprintf('  - Querying: %s\n', current_id);
        
        q2 = InfluxQuery(cfg.Bucket, cfg.Measurement_Name, cfg.InfluxDB_URL, cfg.Token);
        try
            padded_run = pad(char(current_id), 20, 'right', ' ');
            q2 = q2.setAggregation("NONE").getRun(padded_run);
            
            % add dynamic channels
            q2 = q2.addChannel("run_id");
            channels = get_dynamic_channels(excel_file);
            for ch = channels', q2 = q2.addChannel(ch); end
            
            temp_data = q2.Execute();
            
            if ~isempty(temp_data)
                all_run_data = [all_run_data; temp_data];
            else
                warning('Run ID (%s): No data found.', current_id);
            end
        catch ME
            warning('Run ID (%s) failed: %s', current_id, ME.message);
        end
    end
    
    if ~isempty(all_run_data)
        % clean up and preserve input order
        all_run_data.run_id = strip(string(all_run_data.run_id));
        all_run_data = movevars(all_run_data, 'run_id', 'Before', 1);
        
        if ismember('Time', all_run_data.Properties.VariableNames)
            all_run_data = removevars(all_run_data, 'Time');
        end
        
        writetable(all_run_data, output_file, 'Sheet', 'Sheet3');
        fprintf('Success: Saved all Run IDs to Sheet3 (%d total records).\n', height(all_run_data));
        query_performed = true;
    else
        fprintf('[Info] No valid data found for any of the provided Run IDs.\n');
    end
end

%% final import
if query_performed
    fprintf('\nFinalising: Importing %s...\n', output_file);
    uiimport(output_file);
else
    fprintf('\n[Info] No valid data retrieved. Nothing to import.\n');
end
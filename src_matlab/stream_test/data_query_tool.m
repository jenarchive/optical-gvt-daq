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
% startTime = "2026-06-22T10:00:00Z"; % get data between two times
% endTime   = "2026-06-22T11:00:00Z"; % InfluxDB uses UTC (11:00 BST -> 10:00 UTC)
% run_ids = ["run_260622_111509", "run_260622_110829"]; % get data for these runs
output_file = "wt_run_records.xlsx";
query_performed = false; 

do_time_query = exist('startTime', 'var') && exist('endTime', 'var') && ~isempty(startTime);
do_run_query = exist('run_ids', 'var') && ~isempty(run_ids);

if exist(output_file, 'file')
    try
        existing_sheets = sheetnames(output_file);
        if ismember('Sheet1', existing_sheets)
            sheet1_backup = readtable(output_file, 'Sheet', 'Sheet1');
        end
        if ~do_time_query && ismember('Sheet2', existing_sheets)
            sheet2_backup = readtable(output_file, 'Sheet', 'Sheet2');
        end
        if ~do_run_query && ismember('Sheet3', existing_sheets)
            sheet3_backup = readtable(output_file, 'Sheet', 'Sheet3');
        end
        
        delete(output_file);
        
        if exist('sheet1_backup', 'var')
            writetable(sheet1_backup, output_file, 'Sheet', 'Sheet1');
        end
        if exist('sheet2_backup', 'var')
            writetable(sheet2_backup, output_file, 'Sheet', 'Sheet2');
        end
        if exist('sheet3_backup', 'var')
            writetable(sheet3_backup, output_file, 'Sheet', 'Sheet3');
        end
    catch
    end
end

%% time range query
if do_time_query
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
if do_run_query
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
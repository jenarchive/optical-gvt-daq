%% Wind Tunnel Staircase Real-Time Simulation
clear; clc; close all;

%% Config
host = 'http://localhost:8181';
token = 'apiv3_X-YcH5CWvEYkkjDXILY0qhmm9W5jJR0FCgsxWOY_Z4EdHBvGNfiHBIu8fDZU7uujJ87ehrZTlSFLHWJuBxAUCQ';
bucket = 'wind_tunnel_test';
org = 'my-org';

writeUrl = sprintf('%s/api/v2/write?bucket=%s&org=%s&precision=ns', host, bucket, org);
queryUrl = sprintf('%s/api/v3/query_sql?format=json', host);

headerSettings = {
    'Authorization', ['Token ' token];
    'Connection', 'close'
};

writeOptions = weboptions('HeaderFields', headerSettings, ...
    'RequestMethod', 'post', 'ContentType', 'text', 'Timeout', 5);

queryOptions = weboptions('HeaderFields', headerSettings, ...
    'MediaType', 'application/json', 'RequestMethod', 'post', 'Timeout', 5);

run_name = sprintf('run_%s', datestr(datetime('now'), 'yyyymmdd_HHMMSS'));

%% UI setup
figure('Name', 'Wind Tunnel Staircase Flight Monitor', 'NumberTitle', 'off', 'Position', [100, 100, 800, 600]);

subplot(3,1,1); hV = animatedline('Color', 'k', 'LineWidth', 1.5); grid on; ylabel('Velocity (V)'); title(['Run: ' run_name ' (Real-Time)']);
subplot(3,1,2); hA = animatedline('Color', 'r', 'LineWidth', 1.5); grid on; ylabel('Alpha (alpha)');
subplot(3,1,3); hL = animatedline('Color', [0, 0.5, 0], 'LineWidth', 1.5); grid on; ylabel('Lift (L)'); xlabel('Samples');

base_velocities = [30, 50, 70]; 
alpha_sweeps = [2, 4, 6];       
sec_per_point = 4;

startTime = tic;
lastWriteTime = 0; lastQueryTime = 0;
accumulated_lines = {};

fprintf('Starting Wind Tunnel Staircase Simulation... (Close figure to exit)\n');

%% real time loop
while ishandle(gcf)
    currentTime = toc(startTime);
    ts = int64(posixtime(datetime('now')) * 1e9);
    
    point_idx = floor(currentTime / sec_per_point) + 1;
    if point_idx > 9, break; end 
    
    v_idx = floor((point_idx - 1) / 3) + 1;
    a_idx = mod(point_idx - 1, 3) + 1;
    
    current_v = base_velocities(v_idx) + randn() * 0.1;
    current_a = alpha_sweeps(a_idx) + randn() * 0.02;
    current_l = 0.0015 * (current_v^2) * current_a; 
    
    accumulated_lines{end+1} = sprintf(...
        'flight_test_data,run_id=%s,test_point=point_%d velocity=%f,alpha=%f,lift=%f %d', ...
        run_name, point_idx, current_v, current_a, current_l, ts);
    
    %% Batch write
    if currentTime - lastWriteTime >= 1.0
        if ~isempty(accumulated_lines)
            try
                payload = char(strjoin(accumulated_lines, newline));
                webwrite(writeUrl, payload, writeOptions);
                fprintf('Successfully wrote %d lines to InfluxDB\n', length(accumulated_lines));
                accumulated_lines = {};
            catch ME
                fprintf('!! Write Error: %s\n', ME.message);
            end
        end
        lastWriteTime = currentTime;
    end
    
    %% Dynamic query&plot
    if currentTime - lastQueryTime >= 1.5
        try
            q = sprintf("SELECT velocity, alpha, lift FROM flight_test_data WHERE run_id='%s' ORDER BY time ASC", run_name);
            res = webwrite(queryUrl, struct('db', bucket, 'q', q), queryOptions);
            
            if isfield(res, 'records')
                recs = res.records;
            else
                recs = res;
            end
            
            if ~isempty(recs)
                clearpoints(hV); clearpoints(hA); clearpoints(hL);
                
                for i = 1:length(recs)
                    addpoints(hV, i, recs(i).velocity);
                    addpoints(hA, i, recs(i).alpha);
                    addpoints(hL, i, recs(i).lift);
                end
                drawnow limitrate;
                fprintf('Dashboard updated successfully (%d points logged).\n', length(recs));
            end
        catch ME
            fprintf('!! Query Error: %s\n', ME.message);
        end
        lastQueryTime = currentTime;
    end
    
    pause(0.1); 
end

fprintf('Staircase simulation complete.\n');
%% Wind Tunnel Staircase Simulation
clear; clc;

%% Config
host = 'http://localhost:8181';
token = 'apiv3_X-YcH5CWvEYkkjDXILY0qhmm9W5jJR0FCgsxWOY_Z4EdHBvGNfiHBIu8fDZU7uujJ87ehrZTlSFLHWJuBxAUCQ';
bucket = 'wind_tunnel_test'; 
org = 'my-org';

%% Generate fake data
fprintf('Generating data...\n');

run_name = sprintf('run_%s', datestr(datetime('now'), 'yyyymmdd_HHMMSS'));

base_velocities = [30, 50, 70]; 
alpha_sweeps = [2, 4, 6];       
total_points = 90; 
lines = strings(total_points, 1);
base_time = posixtime(datetime('now'));
idx = 1;

for v_step = 1:3
    v_base = base_velocities(v_step);
    for a_step = 1:3
        alpha_base = alpha_sweeps(a_step);
        point_num = (v_step - 1) * 3 + a_step; 
        
        for sample = 1:10
            velocity_val = v_base + randn() * 0.2;
            alpha_val = alpha_base + randn() * 0.05;
            lift_val = 0.0015 * (velocity_val^2) * alpha_val;
            
            ts_ns = int64((base_time + idx) * 1e9); 
            
            lines(idx) = sprintf('flight_test_data,run_id=%s,test_point=point_%d velocity=%f,alpha=%f,lift=%f %d', ...
                               run_name, point_num, velocity_val, alpha_val, lift_val, ts_ns);
            idx = idx + 1;
        end
    end
end
payload = strjoin(lines, newline);

%% Write data
fprintf('Writing data...\n');
writeUrl = sprintf('%s/api/v2/write?bucket=%s&org=%s&precision=ns', host, bucket, org);
options = weboptions('HeaderFields', {'Authorization', ['Token ' token]}, ...
    'RequestMethod', 'post', 'ContentType', 'text', 'Timeout', 10);
webwrite(writeUrl, payload, options);
fprintf('Write successful! Target Run ID: %s\n', run_name);
pause(1);

%% Query data (Dynamically fetch the absolute latest run)
fprintf('Running query...\n');
queryUrl = sprintf('%s/api/v3/query_sql?format=json', host);
queryBody = struct;
queryBody.db = bucket;

% Subquery that automatically finds the latest dynamic run_id
queryBody.q = "SELECT * FROM flight_test_data WHERE run_id = (SELECT run_id FROM flight_test_data ORDER BY time DESC LIMIT 1) ORDER BY time ASC"; 

queryOptions = weboptions('HeaderFields', {'Authorization', ['Token ' token]}, ...
    'MediaType', 'application/json', 'RequestMethod', 'post', 'Timeout', 10);
result = webwrite(queryUrl, queryBody, queryOptions);
fprintf('Query successful!\n');
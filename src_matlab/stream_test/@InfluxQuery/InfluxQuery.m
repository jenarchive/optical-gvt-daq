classdef InfluxQuery < handle
    properties
        Channels string = strings(0,1)
        Database string
        Measurement string
        Tags cell = {}
        ServerURL string
        Token string
        AggregateFunc = "NONE"
        StartTime string = ""
        EndTime string = ""
    end
    
    methods
        function obj = InfluxQuery(Database, Measurement, ServerURL, Token)
            obj.Database = Database;
            obj.Measurement = Measurement;
            obj.ServerURL = ServerURL;
            obj.Token = Token;
        end
        
        function obj = setAggregation(obj, func)
            valid = ["AVG", "MAX", "MIN", "SUM", "COUNT", "NONE"];
            func = upper(func);
            if ismember(func, valid)
                obj.AggregateFunc = func;
            else
                error("Unsupported aggregation function. Choose one of: AVG, MAX, MIN, SUM, COUNT, NONE.");
            end
        end
        
        function obj = setTimeRange(obj, startTime, endTime)
            obj.StartTime = string(startTime);
            obj.EndTime = string(endTime);
        end
        
        function obj = addTag(obj, name, value)
            safe_value = strrep(string(value), "'", "''");
            found = false;
            for i = 1:numel(obj.Tags)
                if strcmp(obj.Tags{i}.Name, name)
                    obj.Tags{i}.Value = safe_value;
                    found = true;
                    break;
                end
            end
            if ~found
                obj.Tags{end + 1} = struct('Name', string(name), 'Value', safe_value);
            end
        end
        
        function obj = getRun(obj, value)
            obj = obj.addTag("run_id", value);
        end
        
        function obj = getTestPoint(obj, value)
            obj = obj.addTag("test_point", value);
        end
        
        function obj = addChannel(obj, name)
            if ~ismember(name, obj.Channels)
                obj.Channels(end + 1) = name;
            end
        end
        
        function QueryString = Build(obj)
            if isempty(obj.Channels)
                error("No channels selected.");
            end
            
            if obj.AggregateFunc ~= "NONE"
                aggChannels = strings(size(obj.Channels));
                for idx = 1:numel(obj.Channels)
                    ch = obj.Channels(idx);
                    aggChannels(idx) = obj.AggregateFunc + '("' + ch + '") AS "' + ch + '"';
                end
                channelStr = strjoin(aggChannels, ", ");
            else
                channelStr = strjoin('"' + obj.Channels + '"', ", ");
            end
            
            QueryString = sprintf('SELECT %s FROM "%s"', channelStr, obj.Measurement);
            
            conditions = strings(0);
            
            if ~isempty(obj.Tags)
                for i = 1:numel(obj.Tags)
                    conditions(end+1) = '"' + obj.Tags{i}.Name + '"' + "='" + obj.Tags{i}.Value + "'";
                end
            end
            
            if strlength(obj.StartTime) > 0 && strlength(obj.EndTime) > 0
                conditions(end+1) = "time >= '" + obj.StartTime + "' AND time <= '" + obj.EndTime + "'";
            elseif strlength(obj.StartTime) > 0
                conditions(end+1) = "time >= '" + obj.StartTime + "'";
            elseif strlength(obj.EndTime) > 0
                conditions(end+1) = "time <= '" + obj.EndTime + "'";
            end
            
            if ~isempty(conditions)
                QueryString = QueryString + " WHERE " + strjoin(conditions, " AND ");
            end
        end
        
        function data = Execute(obj)
            queryString = obj.Build();
            
            endpoint = string(obj.ServerURL) + "/api/v3/query_sql";
            options = weboptions('HeaderFields', ["Authorization", "Bearer " + string(obj.Token)], ...
                'RequestMethod', 'post', 'ContentType', 'json', 'Timeout', 30);
            payload = struct('db', obj.Database, 'q', queryString);
            
            try
                raw_data = webwrite(endpoint, payload, options);
                if isempty(raw_data)
                    data = table();
                else
                    if isstruct(raw_data)
                        data = struct2table(raw_data, 'AsArray', true);
                    elseif iscell(raw_data) && ~isempty(raw_data) && isstruct(raw_data{1})
                        data = struct2table([raw_data{:}], 'AsArray', true);
                    elseif istable(raw_data)
                        data = raw_data;
                    else
                        data = table();
                    end
                end
            catch ME
                warning('Database query failed: %s', ME.message);
                data = table();
            end
        end
    end
end
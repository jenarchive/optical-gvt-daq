classdef InfluxQuery < handle

    properties
        Channels (:,1) string
        Database string
        Measurement string
        Tags (1,:) InfluxTag
        ServerURL string
        Token string
    end

    methods

        function obj = InfluxQuery(Database, Measurement, ServerURL, Token)
            obj.Database = Database;
            obj.Measurement = Measurement;
            obj.ServerURL = ServerURL;
            obj.Token = Token;
        end

        function getTag(obj, name, value)

            if isempty(obj.Tags)
                obj.Tags = InfluxTag(name, value);
            else
                idx = ismember([obj.Tags.Name], name);

                if any(idx)
                    obj.Tags(idx).Value = value;
                else
                    obj.Tags(end + 1) = InfluxTag(name, value);
                end
            end
        end

        function obj = getRun(obj, value)
            obj.getTag("run_id", value);
        end

        function obj = getTestPoint(obj, value)
            obj.getTag("test_point", value);
        end

        function obj = AddChannel(obj, name)

            if isempty(obj.Channels)
                obj.Channels = string.empty;
            end

            if ~ismember(name, obj.Channels)
                obj.Channels(end + 1) = name;
            end
        end

        function QueryString = Build(obj)

            if isempty(obj.Channels)
                error("No channels selected.");
            end

            % channels
            channelStr = strjoin(obj.Channels, ", ");

            % sql select clause
            QueryString = sprintf('SELECT %s FROM "%s"', ...
                channelStr, obj.Measurement);

            % tags
            if ~isempty(obj.Tags)

                conditions = strings(1, numel(obj.Tags));

                for i = 1:numel(obj.Tags)
                    conditions(i) = obj.Tags(i).Name + "='" + string(obj.Tags(i).Value) + "'";
                end

                QueryString = QueryString + " WHERE " + strjoin(conditions, " AND ");
            end
        end

        function data = Execute(obj)

            queryString = obj.Build();

            endpoint = string(obj.ServerURL) + "/api/v3/query_sql";

            options = weboptions( ...
                'HeaderFields', ["Authorization", "Bearer " + string(obj.Token)], ...
                'RequestMethod', 'post', ...
                'ContentType', 'json', ...
                'Timeout', 30);

            payload = struct('db', obj.Database, 'q', queryString);

            try

                % db api call
                raw_data = webwrite(endpoint, payload, options);

                % parse response into table
                data = struct2table(raw_data);

                if ismember("time", data.Properties.VariableNames)
                    data.time = datetime( ...
                        data.time, ...
                        'InputFormat', "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", ...
                        'TimeZone', 'UTC');
                end

                disp("Data retrieved successfully from InfluxDB 3.0.");

            catch ME

                disp("Execution failed: " + ME.message);
                data = table();

            end
        end

    end

end
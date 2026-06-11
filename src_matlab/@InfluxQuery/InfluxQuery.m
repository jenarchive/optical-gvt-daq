classdef InfluxQuery < handle

    properties
        Channels (:,1) string
        Database string
        Tags (1,:) InfluxTag
    end

    methods

        function obj = InfluxQuery(Database)
            obj.Database = Database;
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
            obj = flip(obj);

        end

        function obj = getTestPoint(obj, value)

            obj.getTag("test_point", value);
            obj = flip(obj);

        end

        function obj = AddChannel(obj, name)

            if ~ismember(name, obj.Channels)
                obj.Channels(end + 1) = name;
            end

            obj = flip(obj);

        end

        function QueryString = Build(obj)

            %% channels
            channelStr = join(obj.Channels, ", ");

            QueryString = ...
                "SELECT " + channelStr;

            %% database
            QueryString = ...
                QueryString + " FROM " + obj.Database;

            %% tags
            if ~isempty(obj.Tags)

                tagCells = arrayfun( ...
                    @(t) t.Name + "='" + string(t.Value) + "'", ...
                    obj.Tags);

                tagStr = join(tagCells, " AND ");

                QueryString = ...
                    QueryString + " WHERE " + tagStr;

            end

            QueryString = char(QueryString);

        end

    end

end
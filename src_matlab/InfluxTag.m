classdef InfluxTag

    properties
        Name
        Value
    end

    methods
        function obj = InfluxTag(name,Value)
            obj.Name = name;
            obj.Value = Value;
        end
    end
end
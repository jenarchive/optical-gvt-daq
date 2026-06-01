classdef PolarType
    %POLARTYPE Summary of this class goes here
    %   Detailed explanation goes here
    enumeration
        CPT,CTT,MPT,WPT,Unknown
    end
    methods(Static)
        function obj = parse(str)
            %POLARTYPE Construct an instance of this class
            %   Detailed explanation goes here
            if ismember(str,enumeration('smm.PolarType'))
                obj = smm.PolarType.(str);
            else
                obj = smm.PolarType.Unknown;
            end
        end
    end
end


classdef LogLevel < double
    enumeration 
        INFO(1),WARN(2),ERROR(3)
    end
    methods
        function str = ToString(obj)
            switch obj
                case util.LogLevel.INFO
                    str = "INFO";
                case util.LogLevel.WARN
                    str = "WARN";
                case util.LogLevel.ERROR
                    str = "ERROR";
            end
        end
    end
end


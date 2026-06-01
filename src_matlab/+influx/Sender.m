classdef Sender < handle
    %INFLUXSENDER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        udpObj
        dest string
        port double
    end
    
    methods
        function obj = Sender(dest,port)
            obj.dest = dest;
            obj.port = port;

            obj.udpObj = udpport("byte");
            obj.udpObj.configureTerminator('LF');
        end
        function SendMessage(obj,MessageName,TagNames,TagData,FieldNames,FieldData,timestamp)      
            obj.udpObj.writeline(obj.encode(MessageName,TagNames,TagData,FieldNames,FieldData,timestamp),obj.dest,obj.port);
        end
        function message = encode(~,MessageName,TagNames,TagData,FieldNames,FieldData,timestamp)
            if isempty(TagNames)
                tagStr = MessageName;
            else
                tagStr = join(join([TagNames;TagData]','='),',');
                tagStr = strjoin([MessageName,tagStr],',');
            end
            fieldStr = join(join([FieldNames;FieldData]','='),',');
            message = strjoin([tagStr,fieldStr,string(num2str(timestamp,'%.0f'))]);
%             disp(message)
        end
    end
end


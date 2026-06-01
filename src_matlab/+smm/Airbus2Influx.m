classdef Airbus2Influx<handle
    % Airbus2Influx reads inboundmessage from ACAPS and relays to Influx database 

    properties
        udpObj
        udpInfluxObj
        host string
        port double
        Name string = "Airbus Data Centre"

        UDPSchema udp.Item
        N double = nan;
        TagsIdx
        TagNames
        FieldsIdx
        FieldNames
        FieldData = [];
        BufferIdx double
        Buffer_N double = 50;

        disp_counter = 20;
        disp_idx = 0;

        InfluxUdpObj
        InfluxHost string
        InfluxPort double

        ForwardData logical = true;
    end

    methods
        function SetSchema(obj)
            n = 3;
            obj.UDPSchema        = udp.Item("Project",udp.DataType.string,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("Run",udp.DataType.float,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("Polar",udp.DataType.float,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("DP",udp.DataType.float,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("Sequence",udp.DataType.float,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("Baro",udp.DataType.float,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("Temp",udp.DataType.float,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("AlphaModel",udp.DataType.float,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("AlphaC",udp.DataType.float,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("Q0C",udp.DataType.float,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("Veas",udp.DataType.float,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("V0C",udp.DataType.float,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("M0C",udp.DataType.float,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("REC",udp.DataType.float,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("P0C",udp.DataType.float,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("PI0C",udp.DataType.float,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("T0C",udp.DataType.float,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("Blockage",udp.DataType.float,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("Fz",udp.DataType.float,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("Fy",udp.DataType.float,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("Fx",udp.DataType.float,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("My",udp.DataType.float,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("Mz",udp.DataType.float,BufferSize=n);
            obj.UDPSchema(end+1) = udp.Item("Mx",udp.DataType.float,BufferSize=n);
            obj.N = length(obj.UDPSchema);

            obj.TagsIdx = ismember(1:obj.N,[2,3,5]);
            obj.TagNames = ["RunNum","PolarNum","ScanNum"];
            obj.FieldsIdx = 6:obj.N;
            obj.FieldNames = string([obj.UDPSchema(obj.FieldsIdx).Name]);
            obj.FieldData = nan(obj.Buffer_N,length(obj.FieldNames));
            obj.BufferIdx = obj.Buffer_N;
        end

        function obj = Airbus2Influx(host,port,name,influxHost,influxPort)
            obj.host = host;
            obj.port = port;
            obj.Name = name;
            obj.InfluxHost = influxHost;
            obj.InfluxPort = influxPort;

            obj.SetSchema();

            % setup Airbus data centre Reciever
            obj.udpObj = udpport("byte","IPV4","LocalPort",port,"LocalHost",host);
            obj.udpObj.configureTerminator(double('#'));
            obj.udpObj.UserData = obj;

            % setup influx data sender
            obj.udpInfluxObj = udpport("byte");
            obj.udpInfluxObj.configureTerminator('LF');
            obj.udpInfluxObj.UserData = obj;
        end
        function delete(obj)
            obj.Disconnect()
        end
        function Connect(obj)
            %Start data reciever
            obj.udpObj.configureCallback("terminator",@(src,~)src.UserData.decode(src.readline()))
        end
        function Disconnect(obj)
            obj.udpObj.configureCallback("off")
        end
        function decode(obj,message)
            str_array = strsplit(message,',');
            data_array = str_array(2:2:end-1);
            obj.BufferIdx = mod(obj.BufferIdx,obj.Buffer_N)+1;
            obj.FieldData(obj.BufferIdx,:) = [double(data_array(obj.FieldsIdx))];
            % send to influx
            if obj.ForwardData
                TagData = string([double(data_array(obj.TagsIdx))]);
%                 FieldData = string([double(data_array(obj.FieldsIdx))]);
                obj.SendMessage("ADC",obj.TagNames,TagData,obj.FieldNames,obj.FieldData(obj.BufferIdx,:),influx.timestamp);
            end
        end
        function SendMessage(obj,MessageName,TagNames,TagData,FieldNames,FieldData,timestamp)
            message = obj.encode(MessageName,TagNames,TagData,FieldNames,FieldData,timestamp);
            obj.udpInfluxObj.writeline(message,obj.InfluxHost,obj.InfluxPort);
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
        end
    end
end


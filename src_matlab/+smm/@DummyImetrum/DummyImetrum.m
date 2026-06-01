classdef DummyImetrum < smm.BaseClient
    %HARW Summary of this class goes here
    %   Detailed explanation goes here

    properties
        CameraController imetrum.ControlClient;
        CameraDataSocket imetrum.DataClient;

        template_file = 'c:/qe19391/templates/cantilever_3_pos.vgtemplate'
        data_folder = 'c:/qe19391/data'
    end
    properties
        State imetrum.State = imetrum.State.Idle;
        PauseBetweenScans = false;
        ScanTimer timer
    end
    
    properties
        ForwardData = true;
        TagData string;
        TagNames string;
        InfluxSender influx.Sender;
        InfluxName string

        InfluxTimer timer

        Headers = [];
        Data = [];
        Freq = 30;
        StartTime double= influx.timestamp();
    end

    methods
        function obj = DummyImetrum(SMM_host,SMM_port,Camera_host,Influx_host,Influx_port,Influx_Name,ForwardData)
            arguments
                SMM_host string
                SMM_port double
                Camera_host string
                Influx_host string
                Influx_port double
                Influx_Name string
                ForwardData logical
            end
            obj@smm.BaseClient(SMM_host,SMM_port,'HARW');

            obj.InfluxSender = influx.Sender(Influx_host,Influx_port);
            obj.TagNames = influx.fieldName(["RunNum","PolarNum","ScanNum","IsTesting"]);
            obj.TagData = string([0,0,0,0]);
            obj.Headers = ["Time","UTC"];
            obj.InfluxName = Influx_Name;

            for i = 1:3
                obj.Headers = [obj.Headers,string(sprintf('Position %.0f X',i))];
                obj.Headers = [obj.Headers,string(sprintf('Position %.0f Y',i))];
                obj.Headers = [obj.Headers,string(sprintf('Position %.0f Z',i))];
            end
            obj.Headers = influx.fieldName(obj.Headers);
            obj.Data = zeros(size(obj.Headers));
        end

        function ImetrumConnect(obj)
        end

        function log(obj,message,logLevel)
            arguments
                obj
                message
                logLevel = util.LogLevel.INFO
            end
            %warn SMM
            if logLevel>util.LogLevel.INFO
                obj.SendAdviseMsg(message)
            end
            %send to InfluxDB
            obj.InfluxSender.SendMessage("Log",["Level","Device"],[logLevel.ToString(),"Imetrum"],...
                "Message",influx.string(message),influx.timestamp);   

            switch logLevel
                case util.LogLevel.INFO
                    disp(message)
                case util.LogLevel.WARN
                    warning(message)
                case util.Loglevel.Error
                    error(message)
            end
        end

        function SendData(obj)
            dt = influx.timestamp();
            t = dt-obj.StartTime;
            obj.Data(1:2) = [dt-obj.StartTime,dt]./1e9;
            obj.Data(3:end) = repmat(sin(2*pi*1*(t/1e9)),1,length(obj.Data)-2);
            obj.InfluxSender.SendMessage(obj.InfluxName,obj.TagNames,obj.TagData,obj.Headers,obj.Data,dt);
        end
    end
end


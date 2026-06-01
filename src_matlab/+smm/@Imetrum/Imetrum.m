classdef Imetrum < smm.BaseClient
    % SMM client to control the video gauge camera series

    properties
        CameraController imetrum.ControlClient;
        CameraDataSocket imetrum.DataClient;

        template_file = 'C:/qe19391/HARW/templates/Root_coordinate_position_MP_CT_BM.vgtemplate'
        data_folder = 'C:/qe19391/HARW/data'
    end

    % Health Monitoring Settings
    properties
        HealthMonitor
        HealthMonitorHost string
        HealthMonitorPort double
        TimerHealth timer
        ZeroData double =[];
        DeltaBuffer double =  ones(20,1)*9999;
        DeltaN double = 20;
        DeltaIdx double = 0;
    end

    properties
        State imetrum.State = imetrum.State.Idle;
        PauseBetweenScans = false;
        ScanTimer timer
    end

    methods
        function obj = Imetrum(SMM_host,Camera_host,Influx_host,opts)
            arguments
                SMM_host string
                Camera_host string
                Influx_host string
                opts.Influx_port double = 52000;
                opts.Influx_Name string = "CAM";
                opts.ForwardData logical = true;
                opts.smmPort double = 5000;
                opts.HealthMonitorPort double = 51013;
                opts.HealthHost = SMM_host;
                opts.HealthFrequency double = 10;
            end
            obj@smm.BaseClient(SMM_host,opts.smmPort,'CAM');

            obj.CameraController = imetrum.ControlClient(Camera_host,Name='ImetriumControl');
            obj.CameraDataSocket = imetrum.DataClient(Camera_host,Name='ImetriumData',...
                InfluxHost=Influx_host,InfluxPort=opts.Influx_port,InfluxName=opts.Influx_Name,...
                InfluxTags=["RunNum","PolarNum","ScanNum","IsTesting"],ForwardData=opts.ForwardData);
            obj.CameraDataSocket.TagData = [obj.RunNum,obj.PolarNum,obj.ScanNum,0];

            % Setup Health Monitor
            obj.HealthMonitor = udpport("byte");
            obj.HealthMonitor.configureTerminator(double('#'));
            obj.HealthMonitorHost = opts.HealthHost;
            obj.HealthMonitorPort = opts.HealthMonitorPort;
            obj.TimerHealth = timer(ExecutionMode="fixedRate",Period=1/opts.HealthFrequency,TimerFcn=@(tm,ev)tm.UserData.SendPos());
            obj.TimerHealth.UserData = obj;
        end

        function SendPos(obj)
            Data = obj.CameraDataSocket.Data;
            % Headers = obj.CameraDataSocket.Headings;
            if length(Data)~=8 || length(obj.ZeroData)~=6
                delta = 9999;
                % delta = nan;
            else
                Data = Data(3:end);
                delta = (Data(1:3)+Data(4:6))/2 - ((obj.ZeroData(1:3)+obj.ZeroData(4:6))/2);
                delta = norm(delta);
            end
            obj.DeltaIdx = mod(obj.DeltaIdx,obj.DeltaN)+1;
            obj.DeltaBuffer(obj.DeltaIdx) = delta;
            delta_mean = mean(obj.DeltaBuffer);
            delta_max = max(abs(obj.DeltaBuffer-delta_mean));
            % delta_std = min(99,delta_std*3)/100;

            % val = round(delta_mean,0)+delta_std/100;
            % disp(val)
            message = 'D_USR_FLD_';
            message = addLine(message,'DISP',delta_mean);
            message = addLine(message,'DISPMAX',delta_max);
            message = [message,'#'];

            obj.HealthMonitor.writeline(message,obj.HealthMonitorHost,obj.HealthMonitorPort);
        end



        function Connect(obj)
            Connect@smm.BaseClient(obj);
            obj.CameraController.Connect();
            obj.CameraDataSocket.Connect();
            obj.TimerHealth.start();
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
            obj.CameraDataSocket.InfluxSender.SendMessage("Log",["Level","Device"],[logLevel.ToString(),"Imetrum"],...
                "Message",influx.string(message),posixtime(datetime('now'))*1e9);

            switch logLevel
                case util.LogLevel.INFO
                    disp(message)
                case util.LogLevel.WARN
                    warning(message)
                case util.loglevel.Error
                    error(message)
            end
        end

        function OnPolar(obj,data)
            obj.PolarNum = double(data);
            obj.CameraDataSocket.TagData(2) = obj.PolarNum;
            obj.write('READY');
        end
        function OnRunNumber(obj,data)
            obj.RunNum = double(data);
            obj.CameraDataSocket.TagData(1) = obj.RunNum;
            obj.write('READY');
        end
        function OnZero(obj,~)
            if obj.State ~= imetrum.State.Idle
                obj.log('Warning: Imetrum State Machine must be in the Idle state to start a new test',util.LogLevel.WARN);
                return
            end
            obj.CameraController.LoadTest(filename=obj.template_file,PresetSelection=false);
            pause(2);
            obj.CameraController.SetMode('test');
            pause(0.1)
            obj.CameraController.SetArchive('on');
            pause(0.1)
            obj.CameraController.TestControl('start')
            %get some zero data
            while ~obj.CameraDataSocket.isData
                pause(0.5)
            end
            obj.ZeroData = obj.CameraDataSocket.Data(3:end);
            if obj.PauseBetweenScans
                obj.CameraController.SetArchive('pause');
                obj.State = imetrum.State.TestingWithOutArchive;
            else
                obj.State = imetrum.State.TestingWithArchive;
            end
            % send ready command
            obj.log('Cameras Recording');
            obj.write("READY");
        end

        function OnScan(obj,data)
            if obj.State == imetrum.State.Idle
                obj.log('Warning: Imetrum State Machine must be in a test during a scan',util.LogLevel.WARN)
                return
            end
            obj.ScanNum = obj.ReadScanMessage(data);
            obj.CameraDataSocket.TagData(3) = obj.ScanNum;

            %setup timer
            if ~isempty(obj.ScanTimer)
                obj.ScanTimer.delete
            end
            obj.ScanTimer = timer("TimerFcn",@(obj,~)obj.UserData.EndOfScan(),"StartDelay",obj.ScanDuration+2);
            obj.ScanTimer.UserData = obj;
            %unpause archiving

            if obj.PauseBetweenScans
                obj.CameraController.SetArchive("resume");
                obj.State = imetrum.State.TestingWithArchive;
            end
            obj.log('Starting Scan');
            obj.CameraDataSocket.TagData(4) = 1; % tag to highlight data during a test.
            %start timer
            start(obj.ScanTimer)
        end

        function EndOfScan(obj,~)
            if obj.PauseBetweenScans
                obj.CameraController.SetArchive("pause");
                obj.State = imetrum.State.TestingWithOutArchive;
            end
            obj.CameraDataSocket.TagData(4) = 0;
            obj.log('Scan Complete');
            obj.write("READY");
        end

        function OnCancel(obj,~)
            obj.log('Cancel Recieved. Ending camera recording.',util.LogLevel.WARN);
            obj.OnEnd();
        end

        function OnEnd(obj,~)
            % if pausing between scans take 1 second of data for reference
            if obj.PauseBetweenScans
                obj.CameraController.SetArchive("resume");
                obj.State = imetrum.State.TestingWithArchive;
                pause(1)
            end
            switch obj.State
                case {imetrum.State.TestingWithArchive,imetrum.State.TestingWithOutArchive}
                    obj.CameraController.TestControl('stop');
                    % create fileneame
                    dt = datetime('now');
                    dt.Format = 'ddMMuuuu';
                    day = string(dt);
                    dt.Format = 'HH_mm_ss';
                    daytime = string(dt);
                    run_label = sprintf('run_%.0f_time_%s',obj.RunNum,daytime);
                    filename = fullfile(obj.data_folder,day,run_label,[run_label,'.vgtest']);
                    filename = strrep(filename,'\','/');

                    %save the file
                    res = obj.CameraController.SaveTest(filename,"WithVideo",true);
                    if startsWith(res,"Error")
                        obj.State = imetrum.State.TestingWithOutArchive;
                        obj.log('Error saving Camera Data',util.LogLevel.WARN)
                    else
                        obj.State = imetrum.State.Idle;
                        obj.log('Camera Video Data Saved');
                        obj.write("READY");
                    end
                case imetrum.State.Idle
                    obj.log('Camera System - End while in Idle');
                    obj.write("READY");
            end
            obj.CameraDataSocket.isData = false;
            obj.CameraDataSocket.Data = ones(size(obj.CameraDataSocket.Data))*9999;
        end

    end
end

function message = addLine(message,name,val)
    message = [message,name,',',num2str(val),','];
end


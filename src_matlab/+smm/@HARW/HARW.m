classdef HARW < smm.BaseClient
    %HARW class to control the HARW DAQ system via ACAPS

    % DAQ Properties
    properties
        dq daq.interfaces.DataAcquisition       % DAQ objeect
        RawDataBuffer double                    % buffer for raw data
        DataBuffer double                       % buffer for calibrated data
        DataBufferN = 200*60;                   % Buffer Length
        DataBufferIdx = 1;                      % Next position to fill in buffer
        Gain = [];                              % Channel gains ( to calibrate raw data)
        Offset = [];                            % Channel Offsets ( to calibrate raw data)
        QtrBridge = [];                         % logical array of if a Channel is a Quarter Bridge (requires special treatment)
        Zeroable = [];                          % logical array of if a channel is zeroable ( if zeroable will be zero'ed on OnZero command)
        ChannelNames string                     % Channel names
        KuliteIdx logical                       % Index of Kulite Channels
        AccelIdx logical                        % Index of Accelerometer Channels    
        StrainIdx logical                       % Index of Strain Gauge Channels
        Chanel2InfluxIdx logical                % logical array of channels to stream to the influx datadase
        ChannelMaxVal = [];                     % List of channel max values for health monitoring
        ChannelFile string = "Channels.csv";    % Filename to load channel information from
        DaqSampleRate double                    % Sampling rate to run the DAQ system at
        NOutputs = 2;                           % Number of Output Channels
    end

    % Influx Properties
    properties
        ForwardData = true;                     % indicates whether to stream data to the influx database
        TagNames string = influx.fieldName(["RunNum","PolarNum","ScanNum","IsTesting"]);    % tag names to send to influx
        HeaderNames string                      % Header (Channel) names to send to influx
        InfluxSender influx.Sender;             % web socket       
        InfluxName string = "DAQ";              % Bucket name
        IsTesting logical = false;              % logical boolean to indicate whether a scan is currently active
    end

    % shaker properties - see shaker.ChirpGenerator for details
    properties
        ShakerMode string {mustBeMember(ShakerMode,{'Chirp','Steady'})} = 'Steady'; % enables/diables the chirp
        Amplitude double {mustBeInRange(Amplitude,0,3)} = 0.25;
        Start_Freq double {mustBeInRange(Start_Freq,0,50)} = 1;
        End_Freq double {mustBeInRange(End_Freq,0,50)} = 1;
        BurstPercentage double {mustBeInRange(BurstPercentage,0,1)} = 1;
        WindowBand double {mustBePositive} = 5;
        StartDelay double {mustBeGreaterThanOrEqual(StartDelay,0)} = 1;
        TriggerNum = 0;

        EnforcedDuration double = 0;    % if greater than zero, the length of the scan will be forced to this value (in seconds)

        ChirpBuffer double = []; % The buffer which a generated chirp is stored in, this is then sent in parts to the DAQ
    end

    % Health Monitoring Settings - UDP Socket to send data to ACAPS
    properties
        HealthMonitor
        HealthMonitorHost string
        HealthMonitorPort double
    end

    % Airbus Data Centre Input - udp socket to listen from data from ACAPS
    properties
        AirbusDataStream smm.Airbus2Influx
    end

    % Scan Properties
    properties
        ScanTimer
        ScanStartTime
    end

    % Tip Mass Control Position 
    properties
        MassEnable logical = false;
    end

    % external property updating server
    properties
        PropertyController;
    end

    properties(Dependent)
        TagData;
    end
    methods

        function val = get.TagData(obj)
            % get.TAGDATA depenedent property to get current tag data for influx
            val = [obj.RunNum,obj.PolarNum,obj.ScanNum,obj.IsTesting];
        end
    end


    methods
        function obj = HARW(smmHost,InfluxHost,opts)
            arguments
                smmHost string                              % ACAPS IP
                InfluxHost string                           % Influx IP
                opts.DaqSampleRate double = 400;            % DAQ Sample Rate
                opts.PropertyServerPort double = 4150;      % Port to initlise a property server at ( to remotely change variables)
                opts.Data2Influx logical = true             % Whether to send data to influx
                opts.HealthMonitorPort double = 51013;      % Port to send health data to
                opts.HealthMonitorFreq double= 10;          % freqeuncy at which to send health monitor data
                opts.smmPort double = 5000;                 % ACAPS port numebr
                opts.InfluxPort double = 52000;             % Influx telegraf Port number
                opts.AirbusDataLocalHost string = '192.168.1.191';
                opts.AirbusDataPort double = 51000;
                opts.ChannelFile string = "Channels.csv";
                opts.HealthHost = smmHost;
            end
            % initilse SMM connection
            obj@smm.BaseClient(smmHost,opts.smmPort,'HARW');

            %Intialise DAQ
            obj.dq = daq('ni');
            obj.dq.UserData = obj;
            obj.ChannelFile = opts.ChannelFile;
            obj.ConfigureChannels();
            obj.dq.Rate = opts.DaqSampleRate;

            % setup Influx DB Connection
            obj.InfluxSender = influx.Sender(InfluxHost,opts.InfluxPort);
            obj.TagNames = influx.fieldName(["RunNum","PolarNum","ScanNum","IsTesting"]);
            obj.ForwardData = opts.Data2Influx;

            % Setup Health Monitor
            obj.HealthMonitor = udpport("byte");
            obj.HealthMonitor.configureTerminator(double('#'));
            obj.HealthMonitorHost = opts.HealthHost;
            obj.HealthMonitorPort = opts.HealthMonitorPort;

            % Setup Airbus Data Stream
            obj.AirbusDataStream = smm.Airbus2Influx(opts.AirbusDataLocalHost,opts.AirbusDataPort,"ADC",...
                InfluxHost,opts.InfluxPort);
            obj.AirbusDataStream.ForwardData = false;
            obj.AirbusDataStream.Connect();

            % setup property Update Server
            obj.SetPropertyController(opts.PropertyServerPort);
        end

        function SetPropertyController(obj,PropertyServerPort)
            arguments
                obj
                PropertyServerPort = 4150
            end
            % setup property Update Server
            obj.PropertyController = tcpserver('192.168.1.191',PropertyServerPort,...
                'ConnectionChangedFcn',@(s,e)s.UserData.OnPropServerConnection(s,e));
            obj.PropertyController.UserData = obj;
            obj.PropertyController.configureCallback("terminator",...
                @(src,event)src.UserData.OnPropertyServerRequest(event))
        end
        function SetWindOff(obj)
            % SETWINDOFF settings for a wind off run
            obj.SetChirp(0,30,0.5,50);
        end
        function SetSteady(obj)
            % SETSTEADY settings for a steady run
            obj.ShakerMode = "Steady";
            obj.EnforcedDuration = 5;
        end
        function SetChirp(obj,start_freq,end_freq,amp,duration)
            % SETCHRIP settings for a chirp
            obj.Amplitude = amp;
            obj.ShakerMode = "Chirp";
            obj.Start_Freq = start_freq;
            obj.End_Freq = end_freq;
            obj.BurstPercentage = 0.85;
            obj.WindowBand = 1.5;
            obj.StartDelay = 0.5;
            obj.EnforcedDuration = duration;
        end
        function TriggerScan(obj,ScanNumber,Duration)
            % TRIGGERSCAN Manually triggers a scan
            arguments
                obj
                ScanNumber
                Duration = 0
            end
            if Duration > 0
                obj.EnforcedDuration = Duration;
            end
            obj.OnScan(sprintf('%10d%14f%14f',ScanNumber,-1,0),false);
        end
        function StartDAQ(obj)
            % Start the DAQ object in background mode
            if obj.dq.Running
                obj.dq.stop();
            end
            % clear Buffer;
            f = ceil(obj.dq.Rate);
            obj.dq.flush();
            obj.DataBufferN = f*60;
            obj.DataBuffer = nan(obj.DataBufferN,length(obj.ChannelNames));
            obj.RawDataBuffer = obj.DataBuffer;
            obj.DataBufferIdx = 0;

            % setup DAQ object
            obj.dq.ScansAvailableFcnCount = ceil(f/2)+1;
            obj.dq.ScansAvailableFcn = @(obj,evt)obj.UserData.OnScansAvailable();
            if obj.NOutputs > 0
                obj.dq.ScansRequiredFcnCount = ceil(f)+1;
                obj.dq.ScansRequiredFcn = @(obj,evt)obj.UserData.SetDaqOutput();
                obj.dq.preload(zeros(f*3,obj.NOutputs));
            end

            % Start Forwarding Airbus Data to Influx
            obj.AirbusDataStream.ForwardData = true;

            % start DAQ
            obj.dq.start("Continuous");
        end

        function StopDAQ(obj)
            % stop DAQ
            obj.dq.stop();
            % stop streaming Airbus data to Influx DB
            obj.AirbusDataStream.ForwardData = false;
        end

        function SetDaqOutput(obj,Seconds)
            % SETDAQOUTPUT used to populate the output array sent to the DAQ
            % currently output one is the shaker and if required output two
            % is the mass
            arguments
                obj
                Seconds = 1;
            end
            N = ceil(obj.dq.Rate)*round(Seconds,0);
            % set shaker output
            if isempty(obj.ChirpBuffer)
                out = zeros(N,1);
            elseif size(obj.ChirpBuffer,1)>N
                out = obj.ChirpBuffer(1:N,:);
                obj.ChirpBuffer = obj.ChirpBuffer((N+1):end,:);
            else
                out = [obj.ChirpBuffer;zeros(N,size(obj.ChirpBuffer,2))];
                obj.ChirpBuffer = [];
            end
            % set mass output
            if obj.NOutputs == 2
                out = [out,ones(size(out))*double(obj.MassEnable)];
            end
            obj.dq.write(out);
        end

        function OnPropServerConnection(obj,src,~)
            % OnPropServerConnection small function to highlight when
            % clients connect / disconnect form the property update server
            if src.Connected
                obj.log("Client Connected to property server")
            else
                obj.log("Client Disconnected from property server")
            end
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
                "Message",influx.string(message),posixtime(datetime('now'))*1e9);

            switch logLevel
                case util.LogLevel.INFO
                    disp(message)
                case util.LogLevel.WARN
                    warning(message)
                case util.Loglevel.Error
                    error(message)
            end
        end
    end
end
function OnScan(obj,data,SendReadyCommand)
arguments
    obj
    data
    SendReadyCommand = true
end
if obj.EnforcedDuration>0
    obj.ScanDuration = obj.EnforcedDuration;
end
if strcmp(obj.ShakerMode,"Steady")
    message = sprintf('Starting steady scan with duration %.0f',obj.ScanDuration);
else   
    message = sprintf('Starting scan with Shaker values: Amp %.1f, Freqs [%.1f,%.1f], Duration %.0f',...
        obj.Amplitude,obj.Start_Freq,obj.End_Freq,obj.ScanDuration);
end
obj.log(message,util.LogLevel.INFO)
obj.ScanNum = obj.ReadScanMessage(data);

% setup timer for the end of the scan
%setup timer
if ~isempty(obj.ScanTimer)
    obj.ScanTimer.delete
end

if SendReadyCommand
    % if timer is deleted stopfcn is passed an empty timer - in this case don't
    % send ready command - this allows 'OnCancel' to end a scan without sending
    % 'READY'
    obj.ScanTimer = timer("TimerFcn",@(tm,~)tm.UserData.EndOfScan(),...
        "StopFcn",@(tm,~)SendReady(~isempty(tm),tm),"StartDelay",obj.ScanDuration+2,"UserData",obj);
else
    obj.ScanTimer = timer("TimerFcn",@(tm,~)tm.UserData.EndOfScan(),...
        "StartDelay",obj.ScanDuration+2,"UserData",obj);
end

% generate Chirp Signal
if strcmp(obj.ShakerMode,'Chirp')
    [x,~] = shaker.ChirpGenerator(obj.Start_Freq,obj.End_Freq,obj.ScanDuration,1/obj.dq.Rate,...
        "BurstPercentage",obj.BurstPercentage,"StartDelay",obj.StartDelay,"Window",'Tukey',"WindowBand",obj.WindowBand);
else 
    x = zeros(ceil(obj.dq.Rate),1);
end

%setup Buffer
obj.DataBufferN = ceil(obj.dq.Rate)*(obj.ScanDuration+5);
obj.DataBuffer = nan(obj.DataBufferN,length(obj.ChannelNames));
obj.RawDataBuffer = obj.DataBuffer;
obj.DataBufferIdx = 0;

%start the scan
obj.log('Starting Scan');
obj.ScanStartTime = influx.timestamp();
obj.IsTesting = 1; % tag to highlight data during a test.
obj.ChirpBuffer = x(:)*obj.Amplitude;
start(obj.ScanTimer) % start timer
end

function SendReady(bool,tm)
    if bool 
        tm.UserData.write("READY");
    end
end
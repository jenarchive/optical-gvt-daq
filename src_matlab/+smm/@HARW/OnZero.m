function OnZero(obj,data,SendReadyCommand)
arguments
    obj
    data
    SendReadyCommand = true
end
%%TODO Zero pressure sensors
obj.log('Zero''ing Pressure Sensors');

% if timer is deleted stopfcn is passed an empty timer - in this case don't
% send ready command - this allows 'OnCancel' to end a scan without sending
% 'READY'
if SendReadyCommand
    % if timer is deleted stopfcn is passed an empty timer - in this case don't
    % send ready command - this allows 'OnCancel' to end a scan without sending
    % 'READY'
    obj.ScanTimer = timer("TimerFcn",@(tm,~)tm.UserData.EndOfZero(),...
        "StopFcn",@(tm,~)SendReady(~isempty(tm),tm),"StartDelay",5+2,"UserData",obj);
else
    obj.ScanTimer = timer("TimerFcn",@(tm,~)tm.UserData.EndOfZero(),...
        "StartDelay",5+2,"UserData",obj);
end

%Set Offset to Zero
obj.Offset(obj.Zeroable) = 0;

%Flush Buffer
obj.DataBuffer = nan(obj.DataBufferN,length(obj.ChannelNames));
obj.RawDataBuffer = obj.DataBuffer;
obj.DataBufferIdx = 0;

%start the scan
obj.log('Starting Zero Scan');
obj.ScanStartTime = influx.timestamp();
start(obj.ScanTimer) % start timer
end


function SendReady(bool,tm)
    if bool 
        tm.UserData.write("READY");
    end
end

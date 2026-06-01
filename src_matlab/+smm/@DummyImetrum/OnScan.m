function OnScan(obj,data)
if obj.State ~= imetrum.State.TestingWithArchive && obj.State ~= imetrum.State.TestingWithOutArchive
    obj.log('Warning: Imetrum State Machine must be in a test during a scan',util.LogLevel.WARN)
    return
end
obj.ScanNum = double(data);
obj.TagData(3) = obj.ScanNum;

%setup timer
if ~isempty(obj.ScanTimer)
    obj.ScanTimer.delete
end
obj.ScanTimer = timer("TimerFcn",@(tm,~)tm.UserData.EndOfScan(),"StartDelay",obj.ScanDuration);
obj.ScanTimer.UserData = obj;
%unpause archiving

if obj.PauseBetweenScans
    obj.State = imetrum.State.TestingWithArchive;
end
obj.log('Starting Scan');
obj.TagData(4) = 1; % tag to highlight data during a test.
%start timer
start(obj.ScanTimer)
end
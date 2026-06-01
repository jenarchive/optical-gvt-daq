function OnZero(obj,data)
if obj.State ~= imetrum.State.Idle
    obj.log('Warning: Imetrum State Machine must be in the Idle state to start a new test',LogLevel.WARN);
    return
end
if ~isempty(obj.InfluxTimer)
    delete(obj.InfluxTimer);
end
obj.InfluxTimer = timer("TimerFcn",@(tm,~)tm.UserData.SendData(),...
    "Period",round(1/obj.Freq,3),"ExecutionMode","fixedRate","UserData",obj);
%get some zero data
if obj.PauseBetweenScans
    obj.State = imetrum.State.TestingWithOutArchive;
else
    obj.State = imetrum.State.TestingWithArchive;
end
% send ready command
obj.StartTime = influx.timestamp();
obj.InfluxTimer.start();

obj.log('Cameras Recording');
obj.write("READY");
end
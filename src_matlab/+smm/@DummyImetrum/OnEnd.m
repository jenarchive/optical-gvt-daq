function OnEnd(obj,data)
% if pausing between scans take 1 second of data for reference
if obj.PauseBetweenScans
    obj.State = imetrum.State.TestingWithArchive;
    pause(1)
end
obj.InfluxTimer.stop();
delete(obj.InfluxTimer);
obj.State = imetrum.State.Idle;
obj.log('Camera Video Data Saved');
end
function OnCancel(obj,~)

% check if a scan is running - if so stop it
if obj.IsTesting
    obj.log('Cancel command recieved during test');
    obj.ScanTimer.delete(); % doesn't call 'EndOfScan' or send 'READY' command
    obj.EndOfScan();
else

% call 'OnEnd' method which sends ready command
obj.OnEnd();
end


function OnNew(obj,~)
%Setup Influx Sender
obj.ForwardData = true;
obj.log('DAQ Initilised');
obj.write("READY");
end


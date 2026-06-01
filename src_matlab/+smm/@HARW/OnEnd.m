function OnEnd(obj,~)

% Disable Influx Connection
obj.ForwardData = false;
obj.log('Influx Sender Disabled');

obj.write("READY");
end
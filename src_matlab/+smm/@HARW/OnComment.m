function OnComment(obj,data)
% OnComment - used to change shaker settings via ACAPS 
% split comma seperated values
data = split(data,',');
if strcmp(data(1),"SHKR_MODE")
    % this message is intended to setup the Shaker
    if ~strcmpi(data(2),"chirp")
        % Disable shaker
        obj.ShakerMode = "Chirp";
        obj.Amplitude = 0;
        return
    end
    %enable shaker and set other properties
    props = floor((length(data)-2)/2);
    for i = 1:props
        idx = 3+(i-1)*2;
        switch lower(data(idx))
            case "start_freq"
                obj.Start_Freq = double(data(idx+1));
            case "end_freq"
                obj.End_Freq = double(data(idx+1));
            case "amplitude"
                obj.Amplitude = double(data(idx+1));
            case "burst"
                obj.BurstPercentage = double(data(idx+1))/100;
            case "band"
                obj.WindowBand = double(data(idx+1));
            case "delay"
                obj.StartDelay = double(data(idx+1));
            otherwise
                obj.log(sprintf('Unknown property "%s" set via COMMENT command',lower(data(idx))),util.LogLevel.WARN);
        end
    end   
end
obj.write("READY");
end

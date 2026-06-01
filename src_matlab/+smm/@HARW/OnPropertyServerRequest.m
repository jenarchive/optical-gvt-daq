function OnPropertyServerRequest(obj,~)
%% ONPROPERTYSERVERREQUEST This function handle external reqeust to update 
% the properties of the HARW client. This allows the shaker settings to be
% changed on the fly.
str = obj.PropertyController.readline();
try
    data = jsondecode(str);
catch
    obj.log(sprintf('Error Parsing JSON request: %s',str));
    res = struct();
    res.Error = 'Error Parsing JSON request';
    obj.PropertyController.writeline(jsonencode(res));
    return
end
if isfield(data,'READ')
    res = struct();
    res.WARN = string.empty;
    res.Success = false;
    for i = 1:length(data.READ)
        if isprop(obj,data.READ{i})
            res.(data.READ{i}) = obj.(data.READ{i});
            res.Success = true;
        else
            obj.log(sprintf('Tried to read non-existent property - %s',data.READ{i}),util.LogLevel.WARN);
            res.WARN(end+1) = string(data.READ{i});
        end
    end
    if ~res.Success
        res.Error = 'No Properties Successfully read';
    end
    obj.PropertyController.writeline(jsonencode(res));
elseif isfield(data,'WRITE')
    res = struct();
    res.WARN = string.empty;
    res.Success = true;
    names = string(fieldnames(data.WRITE));
    for i = 1:length(names)
        if isprop(obj,names(i))
            obj.(names(i)) = data.WRITE.(names(i));
            obj.log(sprintf('Set property %s to %s',names(i),string(data.WRITE.(names(i)))));
        else
            obj.log(sprintf('Tried to write to non-existent property - %s',names(i)),util.LogLevel.ERROR);
            res.WARN(end+1) = names(i);
            res.Success = false;
        end
    end
    obj.PropertyController.writeline(jsonencode(res));
elseif isfield(data,'TRIGGER')
    if isfield(data,'DURATION')
        obj.ScanDuration = data.DURATION;
    end
    obj.OnScan(sprintf('%10d%14f%14f',data.TRIGGER,-1,0),false);
    %send response
    res = struct();
    res.isError = false;
    obj.PropertyController.writeline(jsonencode(res));
end
end


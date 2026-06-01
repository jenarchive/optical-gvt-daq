function OnRunNumber(obj,data)
obj.RunNum = double(data);
obj.TagData(1) = obj.RunNum;
obj.write('READY');
end
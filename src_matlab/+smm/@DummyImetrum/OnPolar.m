function OnPolar(obj,data)
obj.PolarNum = double(data);
obj.TagData(2) = obj.PolarNum;
obj.write('READY');
end
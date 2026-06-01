function EndOfScan(obj)
if obj.PauseBetweenScans
    obj.State = imetrum.State.TestingWithoutArchive;
end
obj.TagData(4) = 0;
obj.log('Scan Complete');
obj.write("READY");
end
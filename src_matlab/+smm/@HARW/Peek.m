function data = Peek(obj,n,raw)
% PEEK - see the last n rows of data in the buffer - without removing them.
arguments
    obj
    n = 1
    raw = false;
end
%PEEK Summary of this function goes here
%   Detailed explanation goes here
if raw
    data = obj.RawDataBuffer;
else
    data = obj.DataBuffer;
end
N = size(data,1);
idx = (obj.DataBufferIdx-(n-1)):obj.DataBufferIdx;
idx = mod(idx-1,N)+1;
data = data(idx,:);
end


function EndOfZero(obj)
obj.IsTesting = 0;
pause(0.5) % to ensure the data has been recorded
%% extract buffer data from last 3 seconds
data = obj.DataBuffer;
rawData = obj.RawDataBuffer;
data = data(~isnan(data(:,1)),:);
rawData = rawData(~isnan(rawData(:,1)),:);

[~,idx] = sort(data(:,1));
val = -mean(data(idx(1:(floor(obj.dq.Rate*3))),:));
% deal with quarter Bridge
rawVal = mean(rawData(idx(1:(floor(obj.dq.Rate*3))),:));
val(obj.QtrBridge) = rawVal(obj.QtrBridge);
% Update Offset
obj.Offset(obj.Zeroable) = val(obj.Zeroable);

% Reset buffer
obj.DataBuffer = nan(obj.DataBufferN,length(obj.ChannelNames));
obj.RawDataBuffer = obj.DataBuffer;
obj.DataBufferIdx = 0;

obj.log('Zero''ing Complete');
end
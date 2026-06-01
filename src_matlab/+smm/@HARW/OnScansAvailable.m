function OnScansAvailable(obj)
%% Extract Data
if obj.dq.NumScansAvailable<5
    return
end
[rawData,t,timestamp] = read(obj.dq,obj.dq.NumScansAvailable,OutputFormat="Matrix");
t = (t + posixtime(datetime(timestamp,'ConvertFrom','datenum')))*1e9;
rawData = [t,rawData];
data = rawData;
N = size(rawData,1);
% Quarter Bridge Equation
Vr = (data(:,obj.QtrBridge) - repmat(obj.Offset(obj.QtrBridge),N,1))/10;
data(:,obj.QtrBridge) = -4*Vr./(1+2*Vr).*repmat(obj.Gain(obj.QtrBridge),N,1);
% apply gains and offsets to data
data(:,~obj.QtrBridge) = data(:,~obj.QtrBridge).*repmat(obj.Gain(~obj.QtrBridge),N,1) + repmat(obj.Offset(~obj.QtrBridge),N,1);

%% update Buffer
idx = (obj.DataBufferIdx+1):(obj.DataBufferIdx+N);
idx = mod(idx-1,obj.DataBufferN)+1;
obj.DataBuffer(idx,:) = data;
obj.RawDataBuffer(idx,:) = rawData;
obj.DataBufferIdx = idx(end);

%% Update HealthData
maxVals = max(abs(data))./obj.ChannelMaxVal;
StrainGaugeLimit = max(maxVals(obj.StrainIdx));
if isempty(StrainGaugeLimit)
    StrainGaugeLimit = 99;
end
AccelLimit = max(maxVals(obj.AccelIdx));
if isempty(AccelLimit)
    AccelLimit = 99;
end
SafetyMassPos = maxVals(end);
BufferSize = numel(obj.ChirpBuffer);
if strcmpi(obj.ShakerMode,'Chirp')
    ModeNum = 1;
else
    ModeNum = 0;
end
msg = EncodeHealthData(StrainGaugeLimit,AccelLimit,SafetyMassPos,BufferSize,ModeNum);
obj.HealthMonitor.writeline(msg,obj.HealthMonitorHost,obj.HealthMonitorPort);


%% send data to Influx
if obj.ForwardData
    % tic;
    idx = obj.Chanel2InfluxIdx;
    FieldData = data(:,idx);
    FieldData(isinf(FieldData)|isnan(FieldData)) = 999999999;
    tagStr = join(join([obj.TagNames;obj.TagData]','='),',');
    tagStr = strjoin([obj.InfluxName,tagStr],',');
    fieldStr = join(repmat(obj.HeaderNames,size(data,1),1)+"="+string(FieldData),',');
    ts = string(num2str(data(:,1),'%.0f'));
    message = repmat(tagStr,N,1)+" "+fieldStr+" "+ts;
    l = cumsum(strlength(message));
    i0 = 1;
    for i = 1:length(l)
        if l(i)>32e3 || i == length(l)
            msg = strjoin(message(i0:i),string(newline));
            obj.InfluxSender.udpObj.OutputDatagramSize = strlength(msg)+10;
            obj.InfluxSender.udpObj.writeline(msg,obj.InfluxSender.dest,obj.InfluxSender.port);
            i0=i+1;
            l=l-l(i);
        end
    end
    % toc;
end
end

function message = EncodeHealthData(StrainGaugeLimit,AccelLimit,SafetyMassPos,BufferSize,ModeNum)
            message = 'D_USR_FLD_';
%             addLine = @(message,name,val) [message,name,',',num2str(val),','];
            % message = addLine(message,'DR',DampingRatio);
            message = addLine(message,'SG',StrainGaugeLimit);
            message = addLine(message,'ACC',AccelLimit);
            message = addLine(message,'MASSAFT',~SafetyMassPos);
            message = addLine(message,'CNTDOWN',BufferSize);
            message = addLine(message,'CHIRPON',ModeNum);
            % message = addLine(message,'DISP',7777);
            % message = addLine(message,'DISPMAX',0);
            % for i = 1:length(KulitePressures)
            %     message = addLine(message,['K',num2str(i)],num2str(KulitePressures(i)));
            % end
            message = [message,'#'];
end
function message = addLine(message,name,val)
    message = [message,name,',',num2str(val),','];
end
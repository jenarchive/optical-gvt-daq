function EndOfScan(obj)
obj.IsTesting = 0;
pause(0.5) % to ensure the data has been recorded
%% save buffer data
data = obj.DataBuffer;
rawData = obj.RawDataBuffer;
data = data(~isnan(data(:,1)),:);
rawData = rawData(~isnan(data(:,1)),:);
[~,idx] = sort(data(:,1));
data(:,1) = data(:,1)*1e-9;% convert back to seconds
data = data(idx,:);
rawData = rawData(idx,:);
%create folder
dt = datetime('now');
dt.Format = 'dd_MM_yyyy';
folder = fullfile('data',char(dt));
if ~exist(folder, 'dir')
   mkdir(folder)
end
% create meta data
meta = struct();
meta.Channels = struct();
meta.Channels.Names = obj.ChannelNames;
meta.Channels.Gain = obj.Gain;
meta.Channels.Offset = obj.Offset;
meta.Channels.QtrBridge = obj.QtrBridge;
meta.Run = obj.RunNum;
meta.Polar = obj.PolarNum;
meta.Scan = obj.ScanNum;
meta.IsChirp = strcmpi(obj.ShakerMode,'chirp');
meta.MassForward = data(1,end);
meta.Shaker = struct();
meta.Shaker.Amp = obj.Amplitude;
meta.Shaker.Start_Freq = obj.Start_Freq;
meta.Shaker.End_Freq = obj.End_Freq;
meta.Shaker.BurstPercentage = obj.BurstPercentage;
meta.Shaker.WindowBand = obj.WindowBand;
meta.Shaker.StartDelay = obj.StartDelay;
% get tunnel data
tunnel_data = mean(obj.AirbusDataStream.FieldData);
names = obj.AirbusDataStream.FieldNames;
for i = 1:length(names)
    meta.Tunnel.(names(i)) = tunnel_data(i);
end

% before saving add to the buffers to stop an overflow 
obj.SetDaqOutput(6);

% save the data
dt.Format = 'HHmmss';
name = sprintf('run_%.0f_polar_%.0f_scan_%.0f_time_%s.mat',obj.RunNum,obj.PolarNum,obj.ScanNum,char(dt));
save(fullfile(folder,name),'data','rawData','meta');
obj.log('Scan Data Saved Locally');
nas_folder = fullfile('\\192.168.1.205\HARW-NAS\',folder);
if ~exist(nas_folder, 'dir')
   mkdir(nas_folder)
end
%save to remote location
save(fullfile(nas_folder,name),'data','rawData','meta');
obj.log('Scan Data Saved to NAS');

% Reset buffer
f = ceil(obj.dq.Rate);
obj.DataBufferN = f*60;
obj.DataBuffer = nan(obj.DataBufferN,length(obj.ChannelNames));
obj.RawDataBuffer = obj.DataBuffer;
obj.DataBufferIdx = 0;

% send Meta Data to influx database
FieldNames = ["Run","Polar","Scan","IsChirp","ScanDuration","MassForward","ShakerAmplitude","StartFreq","EndFreq","BurstPercentage","WindowBand","StartTime","EndTime"];
FieldData = [obj.RunNum,obj.PolarNum,obj.ScanNum,strcmpi(obj.ShakerMode,'chirp'),obj.ScanDuration,meta.MassForward,obj.Amplitude,obj.Start_Freq,obj.End_Freq,obj.BurstPercentage,obj.WindowBand,string(num2str(data(1,1)*1e9,'%.0f')),string(num2str(data(end,1)*1e9,'%.0f'))];
for i = 1:length(names)
    FieldNames(end+1) = names(i);
    FieldData(end+1) = tunnel_data(i);
end
fieldStr = join(FieldNames+"="+string(FieldData),',');
ts = string(num2str(data(end,1)*1e9,'%.0f'));
msg = "SCANS"+" "+fieldStr+" "+ts;
obj.InfluxSender.udpObj.OutputDatagramSize = strlength(msg)+10;
obj.InfluxSender.udpObj.writeline(msg,obj.InfluxSender.dest,obj.InfluxSender.port);      

% finished
obj.log('Scan Complete');
end
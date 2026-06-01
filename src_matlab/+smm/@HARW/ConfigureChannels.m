function ConfigureChannels(obj)
% ConfigureChannels configures channels as per the 'ChannelFile'
arguments
    obj smm.HARW
end

% reset arrays
obj.Gain = 1;
obj.Offset = 0;
obj.QtrBridge = false;
obj.Zeroable = false;
obj.KuliteIdx = false;
obj.AccelIdx = false;
obj.StrainIdx = false;
obj.ChannelNames = "Time";
obj.ChannelMaxVal = 1;
obj.Chanel2InfluxIdx = false;
obj.NOutputs = 0;
% configure cards from csv
chs = readtable(obj.ChannelFile);

% disbale NI warnings
warning('off','nidaq:ni:propUpdatedOnAllChannels');
warning('off','nidaq:ni:variationInRates');
warning('off','daq:Session:closestRateChosen');
warning('off','daq:Session:clockedOnlyChannelsAdded');

for i = 1:height(chs)
    % Skip if channel is disabled
    if strcmpi(chs.Disable{i},'true')
        fprintf('---- Skipping Channel: %s ----\n',chs.Name{i});
        continue
    end
    fprintf('---- Setting up Channel: %s ----\n',chs.Name{i});
    if strcmp(chs.Input_Output{i},'in')
        % Here if channel is an input channel
        slot = sprintf('PXI1Slot%.0f',chs.Slot(i));
        switch chs.Measurement_Type{i}
            case 'Strain Gauge'                
                ch = obj.dq.addinput(slot,chs.Channel{i},"Bridge");
                ch.BridgeMode = chs.Bridge_Type{i};
                ch.ExcitationSource = 'Internal';
                ch.ExcitationVoltage = chs.Excitation_Voltage(i);
                ch.NominalBridgeResistance = chs.Resistance(i);
            case 'Accelerometer'
                ch = obj.dq.addinput(slot,chs.Channel{i},"Accelerometer");
                ch.Sensitivity = chs.Sensitivity(i);
            case 'Force Transducer'
                ch = obj.dq.addinput(slot,chs.Channel{i},"IEPE");
            case 'Voltage'
                ch = obj.dq.addinput(slot,chs.Channel{i},"Voltage");
                ch.Range = [-1 1]*chs.Range(i);
            case 'Digital'
                ch = obj.dq.addinput(slot,chs.Channel{i},'Digital');
            otherwise
                ch = daq.Channel.empty;
        end
        if ~isempty(ch)
            ch.Name = chs.Name{i};
            obj.Gain(end+1) = chs.Gain(i);
            obj.Offset(end+1) = chs.Offset(i);
            obj.QtrBridge(end+1) = strcmpi(chs.QtrBridge{i},'true');
            obj.Zeroable(end+1) = strcmpi(chs.Zero{i},'true');
            obj.ChannelNames(end+1) = string(chs.Name{i});
            obj.ChannelMaxVal(end+1) = chs.Max(i);
            obj.Chanel2InfluxIdx(end+1) = strcmpi(chs.ToInflux{i},'true');
            obj.KuliteIdx(end+1) =  startsWith(chs.Name{i},'KP');
            obj.AccelIdx(end+1) =  strcmpi(chs.Measurement_Type{i},'Accelerometer');
            obj.StrainIdx(end+1) =  strcmpi(chs.Output_Unit{i},'strain');
        end
    else
        % Here if channel is an output channel
        slot = sprintf('PXI1Slot%.0f',chs.Slot(i));
        switch chs.Measurement_Type{i}
            case 'Voltage'
                ch = obj.dq.addoutput(slot,chs.Channel{i},"Voltage");
                ch.Range = [-1 1]*chs.Range(i);
                ch.Name = chs.Name{i};
                obj.NOutputs = obj.NOutputs + 1;
            case 'Digital'
                ch = obj.dq.addoutput(slot,chs.Channel{i},"Digital");
                ch.Name = chs.Name{i};
                obj.NOutputs = obj.NOutputs + 1;
        end
    end
end
obj.HeaderNames = influx.fieldName(obj.ChannelNames(obj.Chanel2InfluxIdx));
% reset warnings
warning('on','nidaq:ni:propUpdatedOnAllChannels');
warning('on','nidaq:ni:variationInRates');
warning('on','daq:Session:closestRateChosen');
warning('on','daq:Session:clockedOnlyChannelsAdded');
end
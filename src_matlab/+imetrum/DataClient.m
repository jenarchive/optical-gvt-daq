classdef DataClient < handle
    %IMETRUMCONTROLLER Summary of this class goes here
    %   Detailed explanation goes here

    properties
        tcpObj tcpclient
        host string
        port double
        Name string = "ImetrumData"
    end

    properties
        ImetriumVersion double = nan;
        DataMode imetrum.DataMode = imetrum.DataMode.ascii;
        Headings string = [];
        Data double = [];
        isData = false;
        TimeIdx = nan;
        UTCIdx = nan;
        NTimes = 0;
        NData = 0;

        BufferLock logical = false;
    end
    properties
        ForwardData = true;
        TagData = [];
        TagNames = [];
        InfluxSender influx.Sender;
        InfluxName string
    end

    methods
        function obj = DataClient(host,opts)
            arguments
                host
                opts.Port = 1234;
                opts.Name = 'ImetrumData'
                opts.ForwardData = false;
                opts.InfluxHost = '127.0.0.1'
                opts.InfluxPort = 53000;
                opts.InfluxTags = [];
                opts.InfluxName = 'Cam'
            end
            obj.host = host;
            obj.port = opts.Port;
            obj.Name = opts.Name;
            obj.ForwardData = opts.ForwardData;
            obj.InfluxName = opts.InfluxName;
            obj.TagNames = opts.InfluxTags;
            obj.InfluxSender = influx.Sender(opts.InfluxHost,opts.InfluxPort);
        end
        function Connect(obj)
            obj.isData = false;
            obj.tcpObj = tcpclient(obj.host,obj.port);
            obj.tcpObj.UserData = obj;
            obj.tcpObj.configureTerminator(double(sprintf('\r')));
            pause(0.5);
            obj.tcpObj.configureCallback("terminator",@(tcp,t)tcp.UserData.OnMessageRecieved())
            % deal with any inital messages
            while obj.tcpObj.NumBytesAvailable>2
                obj.OnMessageRecieved();
            end
            obj.tcpObj.flush;
        end
        function OnMessageRecieved(obj)
            while obj.BufferLock
            end
            obj.BufferLock = true;
            message = obj.tcpObj.readline();
            [opcode,data] = obj.ExtractOPCODE(message);
            % remove newline in front of carriage return
            if ~strcmp(opcode,"DATA") || obj.DataMode == imetrum.DataMode.ascii
                if isempty(data(end))
                    data = data(1:(end-1));
                else
                    if ~strcmp(data(end),"")
                        if strcmp(extractAfter(data(end),strlength(data(end))-1),newline)
                            data(end) = extractBefore(data(end),strlength(data(end)));
                        end
                    end
                end
            else
                % check there is enough data
                data = obj.EnsureBinaryDataLength(data);
            end
            obj.BufferLock = false;
            switch opcode
                case "VERSION"
                    obj.ImetriumVersion = double(data(1));
                case "ENCODING"
                    if strcmp("ascii",data(1))
                        obj.DataMode = imetrum.DataMode.ascii;
                    elseif strcmp("binary",data(1))
                        obj.DataMode = imetrum.DataMode.binary; %#ok<*PROP>
                    end
                case "HEADINGS"
                    if str2double(data(1)) == 0 % no headings
                        obj.Headings = string.empty;
                        obj.NData = 0;
                        obj.Data = [];
                    else

                        obj.Headings = influx.fieldName(data(2:end));
                        obj.NTimes = 0;
                        if strcmp(obj.Headings(1),"Time")
                            obj.NTimes = 1;
                            obj.TimeIdx = 1;
                        end
                        if strcmp(obj.Headings(1),"UTC_Time")
                            obj.NTimes = obj.NTimes + 1;
                            obj.UTCIdx = 1;
                        elseif length(obj.Headings)>1 && strcmp(obj.Headings(2),"UTC_Time")
                            obj.NTimes = obj.NTimes + 1;
                            obj.UTCIdx = 2;
                        end
                        obj.NData = length(obj.Headings)-obj.NTimes;
                        obj.Data = zeros(1,obj.NTimes+obj.NData);
                    end
                case "DATA"
                    switch obj.DataMode
                        case imetrum.DataMode.ascii
                            obj.Data = str2double(data);
                            if ~isnan(obj.UTCIdx)
                                obj.Data(obj.UTCIdx) = posixtime(datetime(data(obj.UTCIdx),"InputFormat",'"dd/MM/yyyy HH:mm:ss.SSS"'));
                            end
                        case imetrum.DataMode.binary
                            obj.Data = obj.ExtractBinaryData(data);
                    end
                    obj.isData = true;
                    if obj.ForwardData
                        if isempty(obj.Headings)
                            warning('No Heading availible');
                        else
                            tmp_data = obj.Data;
                            tmp_data(isnan(tmp_data)) = -999999999;
                            tmp_data = arrayfun(@(x)string(num2str(x)),tmp_data);
                            obj.InfluxSender.SendMessage(obj.InfluxName,obj.TagNames,obj.TagData,...
                                obj.Headings,tmp_data,obj.Data(obj.UTCIdx)*1e9);
                        end
                    end
            end

        end
        function [opcode,data] = ExtractOPCODE(obj,message)
            res = split(message,char(9));
            opcode = strrep(res(1),string(newline),"") ;
            data = res(2:end)';
        end

        function charArray = EnsureBinaryDataLength(obj,strData)
            strData = strjoin(strData,char(9));
            charArray = char(strData);
            CorrectLength = (8*obj.NTimes+9*(obj.NData));
            if ~isnan(obj.UTCIdx)
                CorrectLength = CorrectLength+2;
            end
            if length(charArray) == CorrectLength+1
                charArray = charArray(1:end-1);
            else
                while length(charArray)~=CorrectLength+1
                    charArray = [charArray,char(13),char(obj.tcpObj.readline())];
                end
                charArray = charArray(1:end-1);
            end
        end

        function data = ExtractBinaryData(obj,charArray)
            data = zeros(1,obj.NTimes+obj.NData);
            % deal with time
            DataIdx = 1;
            if ~isnan(obj.TimeIdx)
                data(obj.TimeIdx) = typecast(uint8(charArray(((obj.TimeIdx-1)*8+1):(obj.TimeIdx*8))),'double');
                DataIdx = DataIdx+8;
            end
            if ~isnan(obj.UTCIdx)
                data(obj.UTCIdx) = typecast(uint8(charArray(((obj.UTCIdx-1)*8+2):(obj.UTCIdx*8+1))),'double')/1e3;
                DataIdx = DataIdx+10;
            end
            charArray = charArray(DataIdx:end);
            % deal with data
            for i = 1:obj.NData
                isValid = double(charArray(i*9));
                if isValid
                    data(i+obj.NTimes) = typecast(uint8(charArray(((i-1)*9+1):(i*9-1))),'double');
                else
                    data(i+obj.NTimes) = nan;
                end
            end
        end
    end
end


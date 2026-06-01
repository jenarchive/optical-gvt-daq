classdef BaseClient<handle
    % SMMCLIENT A base class to act as a client to the Airbus ACAPS
    % wind tunnel control system - this client will return the OPCODE
    % 'READY' to any recieved OPCODE. Additonal functionality can be
    % achieved by overiding one of the "On<Something>" functions

    
    properties
        tcpObj tcpclient
        host string
        port double
        Name string = "Unknown"
        opcodeLength = 10;
    end

    properties
        Project_dir string = "";
        RunNum double = 0;
        PolarNum double = 0;
        ScanNum double = 0;
        ScanDuration double= 0;
        PolarType smm.PolarType = smm.PolarType.Unknown;
    end
    
    methods
        function obj = BaseClient(host,port,name)
            obj.host = host;
            obj.port = port;
            obj.Name = name;
        end
        function Connect(obj)
            obj.tcpObj = tcpclient(obj.host,obj.port);
            obj.tcpObj.configureTerminator(double('#'));
            obj.tcpObj.UserData = obj;
            pause(2);
            if obj.tcpObj.NumBytesAvailable==11
                obj.tcpObj.configureCallback("terminator",@(tcp,t)tcp.UserData.OnMessageRecieved())
                obj.OnMessageRecieved();
            end
        end
        function Disconnect(obj)
            delete(obj.tcpObj)
%             clear obj.tcpObj
        end
        function log(~,message)
            disp(message)
        end
        function OnMessageRecieved(obj)
            obj.parseOPCODE(obj.tcpObj.readline());
        end
        function SendAdviseMsg(obj,message)
            obj.write('ADVISE_MSG',message)
        end
        function write(obj,opcode,data)
            arguments
                obj
                opcode
                data = ""
            end
            obj.log(sprintf('Sending message with OPCODE %s and data %s',opcode,data))
            opcode = pad(opcode,10,'right','_');
            obj.tcpObj.writeline(sprintf('%s%s',opcode,data));
        end

        function [opcode,data] = ExtractOPCODE(obj,message)
            opcode = extractBefore(message,obj.opcodeLength+1);
            toks = regexp(opcode,"^(.*?)_*$","tokens");
            opcode = toks{1};
            data = extractAfter(message,obj.opcodeLength);
        end

        function parseOPCODE(obj,message)
            [opcode,data] = ExtractOPCODE(obj,message);
            obj.log(sprintf('Message Recieved with OPCODE %s and Data: %s',opcode,data));
            switch opcode
                case "CANCEL"
                    obj.OnCancel(data);
                case "COMMENT"
                    obj.OnComment(data);
                case "D_PROJECT"
                    obj.OnD_Project(data);
                case "D_USR_FLD"
                    obj.OnD_Usr_Fld(data);
                case "END"
                   obj.OnEnd(data);
                case "IDENTIFY"
                    obj.OnIdentify(data);
                case "NEW"
                    obj.OnNew(data);
                case "POLAR"
                   obj.OnPolar(data);
                case "POLAR_TYPE"
                    obj.OnPolarType(data);
                case "RUN_NO"
                    obj.OnRunNumber(data);
                case "SCAN"
                    obj.OnScan(data);
                case "SCAN_DRTN"
                    obj.OnScanDuration(data);
                case "WAIT"
                    obj.OnWait(data);
                case "ZERO"     
                    obj.OnZero(data);
                otherwise
                    obj.OnUnknown(data);
            end
        end
        function OnCancel(obj,~)
            obj.write('READY');
        end
        function OnComment(obj,data)
            obj.log(sprintf('Comment Recieved: %s',data));
            obj.write('READY');
        end
        function OnD_Project(obj,data)
            obj.Project_dir = data;
            obj.write('READY');
        end
        function OnD_Usr_Fld(obj,~)
            obj.write('READY');
        end
        function OnEnd(obj,~)
            obj.write('READY');
        end
        function OnIdentify(obj,~)
            obj.write('IDENTITY',obj.Name);
        end
        function OnNew(obj,~)
            obj.write('READY');
        end
        function OnPolar(obj,data)
            obj.PolarNum = double(data);
            obj.write('READY');
        end
        function OnPolarType(obj,data)
            % record new polar type
            obj.PolarType = smm.PolarType.parse(data);
            if obj.PolarType == smm.PolarType.Unknown
                obj.log(sprintf('Warning: Unknown Polar Type of %s detected',data));
            end
            obj.write('READY');
        end
        function OnRunNumber(obj,data)
            obj.RunNum = double(data);
            obj.write('READY');
        end
        function OnScan(obj,data)
            res = textscan(data,'%10d%14f%14f');
            obj.ScanNum = double(res{1});
            if isnan(obj.ScanNum)
                obj.ScanNum = -1;
            end
            obj.write('READY');
        end
        function OnScanDuration(obj,data)
            obj.ScanDuration = double(data)./1e3;
            obj.write('READY');
        end
        function OnWait(obj,~)
            obj.write('READY');
        end
        function OnZero(obj,~)
            obj.write('READY');
        end
        function OnUnknown(obj,~)
            obj.write('READY');
        end
        
    end
end


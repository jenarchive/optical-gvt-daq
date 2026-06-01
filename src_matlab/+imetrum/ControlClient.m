classdef ControlClient < handle
    %ControlClient client to remotely control and imetrum video gauge
    % instance
    % 
    
    properties
        tcpObj tcpclient
        host string                     % IP address of the imetrum PC
        port double = 1235              % Port for tcp control telnet connection
        Name string = "ImetrumControl"
    end

    methods
        function obj = ControlClient(host,opts)
            arguments
                host
                opts.Port = 1235;
                opts.Name = 'ImetrumControl'
            end
            obj.host = host;
            obj.port = opts.Port;
            obj.Name = opts.Name;
        end
        function SetMode(obj,mode)
            %SETMODE set mode in video gauge to either 'measuements', 'test' or
            %'review'
            arguments
                obj
                mode string {mustBeMember(mode,{'measurements','test','review'})}
            end
            obj.tcpObj.writeline(sprintf('mode %s',mode));
        end
        function SetArchive(obj,mode)
            %SETARCHIVE enable or disable archiving when a test is not
            %running or pause and resume it durnig a test
            arguments
                obj
                mode string {mustBeMember(mode,{'on','off','pause','resume'})}
            end
            obj.tcpObj.writeline(sprintf('set archive %s',mode));
        end
        function TestControl(obj,mode,opts)
            %TESTCONTROL 
            arguments
                obj
                mode string {mustBeMember(mode,{'start','stop','next'})}
                opts.NFrames = nan;
            end
            if strcmp(mode,"start") && ~isnan(opts.NFrames)
                obj.tcpObj.writeline(sprintf('test %s numframes=%.0f',mode,opts.NFrames));
            else
                obj.tcpObj.writeline(sprintf('test %s',mode));
            end
        end
        function LoadTest(obj,opts)
            arguments
                obj
                opts.filename = nan;
                opts.CurrentSettings = true;
                opts.PresetSelection = true;
                opts.PresetID = nan;
            end
            test_cmd = 'test new using_cameras';
            if ~isnan(opts.filename)
                test_cmd = sprintf('%s from_template %s',test_cmd,opts.filename);
            elseif opts.CurrentSettings
                test_cmd = [test_cmd,' using_current_settings'];
            end
            if ~opts.PresetSelection
                test_cmd = [test_cmd,' no_preset_selection'];
            end
            if ~isnan(opts.PresetID)
                test_cmd = sprintf('%s preset_id %s',test_cmd,opts.filename);
            end
            obj.tcpObj.writeline(test_cmd);
        end
        function res = SaveTest(obj,filename,opts)
            arguments
                obj
                filename
                opts.WithVideo = true;
            end
            obj.tcpObj.flush()
            if opts.WithVideo
                res = obj.tcpObj.writeread(sprintf('save withvideo %s',filename));
            else
                res = obj.tcpObj.writeread(sprintf('save withoutvideo %s',filename));
            end
        end
        function Connect(obj)
            obj.tcpObj = tcpclient(obj.host,obj.port);
            obj.tcpObj.configureTerminator(double(newline));
            pause(0.5);
            %ensure controller is silent
            obj.tcpObj.writeline('set status off')
            obj.tcpObj.writeline('set notifications off')
            pause(0.25);
            obj.tcpObj.flush;
        end
    end
end


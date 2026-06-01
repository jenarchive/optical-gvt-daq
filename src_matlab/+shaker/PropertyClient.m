classdef PropertyClient
    %HARWPROPERTYCLIENT Summary of this class goes here
    %   Detailed explanation goes here

    properties
        tc tcpclient
    end

    methods
        function obj = PropertyClient(host,port)
            %HARWPROPERTYCLIENT Construct an instance of this class
            %   Detailed explanation goes here
            obj.tc = tcpclient(host,port);
        end
        function ReadChirpSettings(obj)
            obj.tc.flush;
            req = struct();
            req.READ = ["ShakerMode","Amplitude","Start_Freq","End_Freq","BurstPercentage","WindowBand","StartDelay","EnforcedDuration"];
            res = obj.tc.writeread(jsonencode(req));
            try
                json_data = jsondecode(res);
                if isempty(json_data.WARN)
                    for i = 1:length(req.READ)
                        fprintf('%s: %s\n',req.READ(i),string(json_data.(req.READ(i))));
                    end
                end
            catch
                fprintf('Error Parsing JSON result: %s\n',string);
            end
        end
        function TriggerTest(obj,ScanNum,Duration)
            obj.tc.flush;
            req = struct();
            req.TRIGGER = ScanNum;
            req.DURATION = Duration;
            % send request
            res = obj.tc.writeread(jsonencode(req));
            % process resposne
            try
                json_data = jsondecode(res);
                if json_data.isError
                    fprintf('Failed to Write Settings to HARW\n');
                end
            catch
                fprintf('Error Parsing JSON result: %s\n',string);
            end
        end
        function DisableChirp(obj)
            obj.tc.flush;
            req = struct();
            req.WRITE.ShakerMode = 'Steady';
            req.WRITE.Amplitude = 0;
            req.WRITE.EnforcedDuration = 0;
            % send request
            res = obj.tc.writeread(jsonencode(req));
            % process resposne
            try
                json_data = jsondecode(res);
                if ~json_data.Success
                    fprintf('Failed to Write Settings to HARW\n');
                end
            catch
                fprintf('Error Parsing JSON result: %s\n',string);
            end

        end

        function EnableChirp(obj,Freqs,Amplitude,opts)
            arguments
                obj
                Freqs
                Amplitude
                opts.BurstPercentage = 1;
                opts.WindowBand = 5;
                opts.StartDelay = 1;
                opts.EnforcedDuration = 0;
            end
            obj.tc.flush;
            % build reqeuest
            req = struct();
            req.WRITE.ShakerMode = 'Chirp';
            req.WRITE.Amplitude = Amplitude;
            req.WRITE.Start_Freq = Freqs(1);
            req.WRITE.End_Freq = Freqs(2);
            req.WRITE.BurstPercentage = opts.BurstPercentage;
            req.WRITE.WindowBand = opts.WindowBand;
            req.WRITE.StartDelay = opts.StartDelay;
            req.WRITE.EnforcedDuration = opts.EnforcedDuration;
            % send request
            res = obj.tc.writeread(jsonencode(req));
            % process resposne
            try
                json_data = jsondecode(res);
                if ~json_data.Success
                    fprintf('Failed to Write Settings to HARW\n');
                end
            catch
                fprintf('Error Parsing JSON result: %s\n',string);
            end

        end
    end
end


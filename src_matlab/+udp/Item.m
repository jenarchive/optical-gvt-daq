classdef Item < handle
    %AIRBUSUDPDATASTRUCTURE Summary of this class goes here
    %   Detailed explanation goes here
    properties
        Name string
        Type udp.DataType
    end
    properties
        N = 100;
        Buffer = inf(100,1);        
        BufferIdx = 0;
    end
    properties(Dependent)
        Value
    end

    methods
        function val = get.Value(obj)
            val = obj.Buffer(obj.BufferIdx);
        end
        function set.Value(obj,val)
            obj.BufferIdx = obj.BufferIdx + 1;
             obj.BufferIdx = mod(obj.BufferIdx-1,obj.N)+1;
             obj.Buffer(obj.BufferIdx) = val;
        end
        function val = Mean(obj,opts)
            arguments
                obj
                opts.N = obj.N
            end
            if obj.Type == udp.DataType.string
                val = obj.Buffer(obj.BufferIdx);
                return
            end
            if opts.N<obj.N
                idx = (obj.BufferIdx-(opts.N-1)):obj.BufferIdx;
                idx = mod(idx-1,obj.N)+1;
                val = mean(obj.Buffer(idx));
            else
                val = mean(obj.Buffer);
            end
        end
    end

    methods
        function obj = Item(Name,type,opts)
            arguments
                Name
                type
                opts.BufferSize = 100;
            end
            obj.Name = Name;
            obj.Type = type; 

            obj.N = opts.BufferSize;
            switch type
                case udp.DataType.float
                    obj.Buffer = inf(obj.N,1);  
                case udp.DataType.string
                    obj.Buffer = strings(obj.N,1);
            end
            obj.BufferIdx = obj.N;
        end
    end
    methods  
        function message = encode(obj,data)
            arguments
                obj
                data = obj.Value
            end
            switch obj.Type
                case UDPDataType.string
                    message = [char(obj.Name),',',char(data),','];
                case UDPDataType.float
                    message = [char(obj.Name),',',num2str(data),','];
            end
        end
    end
end


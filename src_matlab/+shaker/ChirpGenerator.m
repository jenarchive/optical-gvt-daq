function [x,t,t_idx,x_chirp,f_chirp,w_chirp] = ChirpGenerator(StartFreq,EndFreq,Duration,dt,opts)
arguments
    StartFreq
    EndFreq
    Duration
    dt
    opts.BurstPercentage = 1;
    opts.StartDelay = 0;
    opts.Amplitude = 1;
    opts.Type string {mustBeMember(opts.Type,{'Linear','Exponential'})}= 'Linear'
    opts.Phase_0 = 0;
    opts.Window string {mustBeMember(opts.Window,{'None','Hann','Tukey'})} = 'Tukey'
    opts.WindowBand = 5; % number of seconds to get to max amplitude
end

% calc time series
N = floor(Duration/dt);
Duration = N*dt;
t = 0:dt:Duration;


% split time into 3 section
% t_0 -> t_1 (Pre-Chirp)
% t_1 -> t_2 (Chirp)
% t_2 -> t_3 (Post-Chirp)
t_1 = round(opts.StartDelay/dt)*dt;
t_2 = t_1 + (Duration - t_1)*opts.BurstPercentage;

%% build the chirp
ChirpDuration = t_2-t_1;
t_chirp = 0:dt:ChirpDuration;
N_chirp = length(t_chirp);
switch opts.Type
    case "Linear"
        c = (EndFreq - StartFreq)/ChirpDuration;
        f_chirp = c.*t_chirp + StartFreq;
        x_chirp = sin(opts.Phase_0 + 2*pi*(c/2.*t_chirp.^2 + StartFreq.*t_chirp));
    case "Exponential"
        k = (EndFreq/StartFreq).^(ChirpDuration./t_chirp);
        f_chirp = 1/StartFreq*k.^(t_chirp./ChirpDuration);
        x_chirp = sin(opts.Phase_0 + 2*pi*1/StartFreq.*(k.^(t_chirp/ChirpDuration)-1)./log(k));
end
%% apply window
switch opts.Window
    case "None"
        w_chirp = ones(size(x_chirp));
    case "Hann"
        w_chirp = sin(pi*(0:(N_chirp-1))/N_chirp).^2;
    case "Tukey"
        if ChirpDuration<=opts.WindowBand*2
            w_chirp = sin(pi*(0:(N_chirp-1))/N_chirp).^2;
        else
            w_chirp = ones(size(x_chirp));
            alpha = 2*opts.WindowBand/(dt*N_chirp);
            n = 0:N_chirp;
            %accel region
            idx = t_chirp<opts.WindowBand;
            w_chirp(idx) = 0.5*(1-cos(2*pi*n(idx)./(alpha*N_chirp)));
            %decel region
            idx = t_chirp>(ChirpDuration-opts.WindowBand);
            w_chirp(idx) = 0.5*(1-cos(2*pi*(N_chirp-n(idx))./(alpha*N_chirp)));
        end
end
x_chirp = x_chirp .* w_chirp;

%% build full signal
x = zeros(size(t));
t_idx = t>=t_1 & t<=t_2;
x(t_idx) = x_chirp;

end


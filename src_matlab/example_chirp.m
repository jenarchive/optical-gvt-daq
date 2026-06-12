%% script to test the function to generate a chrip signal

Freqs = [0 30];  % start and end freqeuncy of the chirp
Duration = 40;      % Chirp Duration
StartDelay = 0;     % delay at start of signal before chirp starts
Burst = 0.9;        % percentage of duration over which chirp occurs 
%                       e.g.(0.9 and 40s chirp mean chirp will be in first 36s of signal)
dt = 1/1000;        % period

% option 1
Type = "Linear";    % type of chirp
Window = "Hann";    % windowwing function to apply to chirp

% option 2
Band = 2;           % for Tukey window, specifies number of seconds to get to max output
Type = "Linear";    % type of chirp
Window = "Tukey"; % windowwing function to apply to chirp



[x,t,t_idx,x_chirp,f_chirp,w_chirp] = shaker.ChirpGenerator(Freqs(1),Freqs(2),Duration,dt,...
    "BurstPercentage",Burst,"StartDelay",StartDelay,"Type",Type,"Window",Window,"WindowBand",Band);

% 
% f = figure(1);
% clf;
% plot(t,x);

f = figure(2);
clf;
tt = tiledlayout(2,2);
nexttile(1);
plot(t,x);
xlabel('time [s]')
title('Chirp Signal')
nexttile(3);
t_chirp = t(t_idx)-min(t(t_idx));
plot(t_chirp,w_chirp);
xlabel('time [s]')
title('Window Function')
nexttile(2,[2,1])
[f,P1] = farg.signal.psd(x_chirp,1/dt);
plot(f,P1);
xlim([0 max(Freqs)+5])
xlabel('Freq [Hz]')
title('PSD')
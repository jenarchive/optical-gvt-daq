% script to setup the HARW DAQ matlab object and example commands used
% during testing


%% clear all objects and clear all timers
clear all
t = timerfindall;
for i =1:length(t)
    t(i).delete;
end
clear all;
pause(1)

%% setup HARW DAQ object
hw = smm.HARW('192.168.1.25','localhost',HealthHost='192.168.1.23',smmPort=5000); % create object
hw.Connect; % connect to ACAPS
hw.StartDAQ; % start the data aquisition



%% example commands
% hw.StopDAQ; % stop data aquisition
% hw.MassEnable = true; % trigger tip mass into aft position
% hw.SetWindOff; % setup Shaker for a wind off run (50 second chirp, 0-30Hz, 0.5V amplitude)
% hw.SetSteady;    % setup a steady run (no shaker), default 5 second run;
% hw.EnforcedDuration = 60; enforce run duration (useful for steady runs)
% hw.TriggerScan(<Run Number>); % trigger a manual scan
% hw.SetChirp(0,50,0.75,80); % CHIRP50 setup: 80 second chirp, 0-50Hz, 0.75V amplitude
% hw.SetChirp(0,20,1,50); % CHIRP20 setup: 50 second chirp, 0-20Hz, 1V amplitude
% hw.SetChirp(0,30,0.75,40); % CHIRP30 setup: 40 second chirp, 0-30Hz, 0.75V amplitude
% hw.Peek; see last row of data in the data buffer













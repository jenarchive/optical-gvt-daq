% script to setup the HARW CAM matlab object and example commands used
% during testing
% this object was used to communicate with the imetrum camera system and
% stream live data to ACAPS and influx.


%% clear all objects and clear all timers
clear all
t = timerfindall;
for i =1:length(t)
    t(i).delete;
end
clear all;
pause(1)


%% setup HARW CAM object
im = smm.Imetrum('192.168.1.25','192.168.1.190','localhost',HealthHost='192.168.1.23',smmPort=5000); % create object
im.Connect; % connect to ACAPS


%% example commands
% im.CameraController.SetArchive('pause'); % stop saving video to file (but still stream live data)
% im.CameraController.SetArchive('resume'); % resume saving video to file











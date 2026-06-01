function res = timestamp()
%TIMESTAMP Summary of this function goes here
%   Detailed explanation goes here
res = posixtime(datetime('now'))*1e9;
end


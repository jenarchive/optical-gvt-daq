function res = fieldName(var)
%FIELDNAME Summary of this function goes here
%   Detailed explanation goes here
res = strtrim(var);
% res = strrep(res," ","\ ");
res = strrep(res," ","_");
end


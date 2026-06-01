function str = string(var)
%STRING Summary of this function goes here
%   Detailed explanation goes here
str = string(var);
str = strjoin(["""",str,""""],"");
end


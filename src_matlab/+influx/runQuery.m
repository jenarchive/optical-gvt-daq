function data = runQuery(measurement,run,opts)
% RUNQUERY API to get all influx data for a specific run
arguments
    measurement string
    run double
    opts.ip string = '192.168.1.191'
    % opts.token string = "N_68ypyskRaeebgB5gd7TiF45A9B9vmdZwQQZUDakpwJgijpe8ieLiWm1Yq_dvZEJ0JZ6yJweniMat_bX4M6BQ=="
    opts.token string = "K_X_pfv3BSBF7czVvWF1JmrMo1b1jlBMb-ROUqyZYrac78OONANSuOl9ac7KW0_E-VIURP8s0X-1Ma3k87otdA=="
    opts.bucket string = "HARW"
end

%create query
q = [sprintf('from(bucket: "%s")',opts.bucket),...
' |> range(start: 0, stop: 1d)',...
sprintf('|> filter(fn: (r) => r["_measurement"] == "%s")',measurement),...
sprintf('|> filter(fn: (r) => r["RunNum"] == "%.0f")',run),...
'|> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")',...
'|> map(fn: (r) => ({r with unix_time: uint(v: r._time)}))',...
'|> drop(columns: ["_start","_stop","host","_measurement"])',...
'|> yield()'];

%send query
body = matlab.net.http.MessageBody(q);
contentTypeField = matlab.net.http.field.ContentTypeField('application/vnd.flux'); %Flux being the field name
acceptField = matlab.net.http.field.AcceptField('application/csv');
method = matlab.net.http.RequestMethod.POST;
auth = matlab.net.http.field.GenericField('Authorization',sprintf('Token %s',opts.token)); %ImZX1... being the token of bucket
header = [acceptField auth contentTypeField]; 
request = matlab.net.http.RequestMessage(method,header,body);

uri = matlab.net.URI(sprintf('http://%s:8086/api/v2/query?org=UoB',opts.ip)); %XYZ being the https, ABC being the key
response = send(request,uri);
data = response.Body.Data;
end
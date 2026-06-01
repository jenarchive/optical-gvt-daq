function data = metaQuery(opts)
% METAQUERY API to get influx meta data for each run
arguments
    opts.Range
    opts.ip string = '192.168.1.191'
    opts.token string = "K_X_pfv3BSBF7czVvWF1JmrMo1b1jlBMb-ROUqyZYrac78OONANSuOl9ac7KW0_E-VIURP8s0X-1Ma3k87otdA=="
    opts.bucket string = "HARW"
    opts.measurement string = "SCANS"
end

%create query
q = [sprintf('from(bucket: "%s")',opts.bucket),...
    ' |> range(start: 0, stop: 1d)',...
    sprintf('|> filter(fn: (r) => r["_measurement"] == "%s")',opts.measurement),...
    '|> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")',...
    '|> map(fn: (r) => ({r with unix_time: uint(v: r._time)}))',...
    '|> drop(columns: ["_start","_stop","host","Var1","result","_measurement"])',...
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

data.Var1 = [];
data.result = [];
data.table = [];
end
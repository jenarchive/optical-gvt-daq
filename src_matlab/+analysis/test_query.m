% Build an InfluxDB client
URL = 'http://localhost:8086';
TOKEN = 'R3dbu310HJ!';
ORG = 'qe19391';
DATABASE = 'HARW';
influxdb = InfluxDB(URL, ORG, TOKEN, DATABASE);







data = 'SELECT * FROM SMM WHERE run=''1''';
result = influxdb.runQuery(data)
d = result.series('SMM').field('Pressure')
% data = 'SELCT "Pressure" FROM "SMM" WHERE "run" = 1';

% body = matlab.net.http.MessageBody(data);
% contentTypeField = matlab.net.http.field.ContentTypeField('application/json'); %Flux being the field name
% acceptField = matlab.net.http.field.AcceptField('application/csv');
% method = matlab.net.http.RequestMethod.POST;
% % auth = matlab.net.http.field.GenericField('Authorization','Token -DlKhoIDU4mP0zszlDC6h7z-8goTdlURySPxu_3_Dgk5mHWW2EiNonDiGcZ5mePNrw1k3A=='); %ImZX1... being the token of bucket
% header = [acceptField contentTypeField]; 
% request = matlab.net.http.RequestMessage(method,header,body);
% 
% uri = matlab.net.URI('https://localhost:8086/query?org=UOB'); %XYZ being the https, ABC being the key
% response = send(request,uri);

% data = ['from(bucket: "HARW")',...
%   '|> range(start: v.timeRangeStart, stop: v.timeRangeStop)',...
%   '|> filter(fn: (r) => r["_measurement"] == "SMM")',...
%   '|> filter(fn: (r) => r["_field"] == "Pressure")',...
%   '|> filter(fn: (r) => r["run"] == "1")',...
%   '|> filter(fn: (r) => r["polar"] == "1")',...
%   '|> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)',...
%   '|> yield(name: "mean")'];
% 
% % result = influxdb.runQuery(query);
% % 
% % 
% % 
% % "curl --request -G http://localhost:8086/query?orgID=INFLUX_ORG_ID&database=MyDB&retention_policy=MyRP --header 'Authorization: Token INFLUX_TOKEN' --header 'Accept: application/csv' --header 'Content-type: application/json' --data-urlencode ""q=SELECT used_percent FROM example-db.example-rp.example-measurement WHERE host=host1"""
% % 
% % 
% % 
% % data = 'from(bucket: "HARW") |> range(start: -3h)'; %ABCD Being the bucket name
% body = matlab.net.http.MessageBody(data);
% contentTypeField = matlab.net.http.field.ContentTypeField('application/vnd.flux'); %Flux being the field name
% acceptField = matlab.net.http.field.AcceptField('application/csv');
% method = matlab.net.http.RequestMethod.POST;
% % auth = matlab.net.http.field.GenericField('Authorization','Token k62wJnhNMidQXxzzol3iffAA-7wDvb7YWb3Seuc-Kcrr9oU-6ckAG0vc8a571X-5lzrafJ47NadVkXzarMvgdg=='); %ImZX1... being the token of bucket
% header = [acceptField contentTypeField]; 
% request = matlab.net.http.RequestMessage(method,header,body);
% 
% uri = matlab.net.URI('https://localhost:8086/api/v2/query?orgID=UoB'); %XYZ being the https, ABC being the key
% response = send(request,uri);
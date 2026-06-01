% Build an InfluxDB client
URL = 'https://127.0.0.1:8086';
TOKEN = 'R3dbu310HJ!';
ORG = 'qe19391';
DATABASE = 'UoB';
% influxdb = InfluxDB(URL, ORG, TOKEN, DATABASE);



q = ['from(bucket: "HARW")',...
  '|> range(start: v.timeRangeStart, stop: v.timeRangeStop)',...
  '|> filter(fn: (r) => r["_measurement"] == "Cam")',...
  '|> filter(fn: (r) => r["IsTesting"] == "1")',...
  '|> filter(fn: (r) => r["RunNum"] == "104")',...
  '|> filter(fn: (r) => r["PolarNum"] == "2")',...
  '|> filter(fn: (r) => r["ScanNum"] == "1")',...
  '|> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")'];

url = [URL,'/api/v2/query?org=',DATABASE];

% hf{1,1} = 'Authorization';
% hf{1,2} = 'Token 7ZEp7GUjce5Xpv1IghcJjm87idzHGJbbbpEZEIWHPHXKsZ0hT_CH77N8On5ao3moG0M428lXEn_8xdGwEXQ0Tw==';
hf{1,1} = 'Accept';
hf{1,2} = 'application/csv';
hf{2,1} = 'Content-type';
hf{2,2} = 'application/vnd.flux';
opts = weboptions('Timeout', 10,'HeaderFields',hf);
params = {['u=' ORG],['p=' TOKEN],['db=' DATABASE], ['q=' q]};
            url = [url '&' strjoin(params, '&')];

response = webread(url, opts);


% q = 'from(bucket: "HARW") |> range(start: -1h)'; %ABCD Being the bucket name
% body = matlab.net.http.MessageBody(q);
% contentTypeField = matlab.net.http.field.ContentTypeField('application/vnd.flux'); %Flux being the field name
% acceptField = matlab.net.http.field.AcceptField('application/csv');
% method = matlab.net.http.RequestMethod.POST;
% auth = matlab.net.http.field.GenericField('Authorization','Token Fjw7f23LcNTr3CZu-DlKhoIDU4mP0zszlDC6h7z-8goTdlURySPxu_3_Dgk5mHWW2EiNonDiGcZ5mePNrw1k3A=='); %ImZX1... being the token of bucket
% header = [auth acceptField contentTypeField]; 
% request = matlab.net.http.RequestMessage(method,header,body);
% 
% uri = matlab.net.URI(url); %XYZ being the https, ABC being the key
% response = send(request,uri)



% data = 'from(bucket: "HARW") |> range(start: -1h)'; %ABCD Being the bucket name
% body = matlab.net.http.MessageBody(data);
% contentTypeField = matlab.net.http.field.ContentTypeField('application/vnd.flux'); %Flux being the field name
% acceptField = matlab.net.http.field.AcceptField('application/csv');
% method = matlab.net.http.RequestMethod.POST;
% auth = matlab.net.http.field.GenericField('Authorization','Token ImZX1uYRmhNTUeU7m4tyHoDiTy39Ao4NV2-9IyzfgOSvEQN7zYMpzuPNqyFAk6RaC330-W7yEPR2SiMaQhIFAQ=='); %ImZX1... being the token of bucket
% header = [auth acceptField contentTypeField]; 
% request = matlab.net.http.RequestMessage(method,header,body);
% 
% uri = matlab.net.URI('https://127.0.0.1:8086/api/v2/query?org=UoB'); %XYZ being the https, ABC being the key
% response = send(request,uri)



% d = result.series('SMM').field('Pressure')
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
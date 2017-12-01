unit SetDBPath;

interface


procedure SetDatabasePath(configPath : String; newPath : String;
                          databaseName : String;
                          userId, password : String;
                          hostName : String;
                          hostPort : Integer);

implementation
uses
  sysUtils,
  strUtils,

  edbcomps;

procedure SetDatabasePath(configPath : String; newPath : String;
													databaseName : String;
                          userId, password : String;
                          hostName : String;
                          hostPort : Integer);
var
	db : TEDBDatabase;
  session : TEDBSession;
	ds : TEDBQuery;
begin
  engine.ConfigPath  := configPath;

  session := TEDBSession.Create(nil);
  session.AutoSessionName := true;
  session.SessionType := stRemote;
  session.LoginUser := userId;
  session.LoginPassword := password;
  if AnsiLeftStr(hostName, 2) = '\\' then
		session.RemoteHost := AnsiRightStr(hostName, length(hostName) - 2)  // '\\hostname'
  else
	  session.RemoteAddress := hostName; //'127.0.0.1';
  session.RemotePort := hostPort; //12010;

  db := TEDBDatabase.Create(nil);
  db.SessionName := session.Name;
  db.Database := 'Configuration';
  db.LoginPrompt := true;
  db.DatabaseName := databaseName + DateTimeToStr(now);

  ds := TEDBQuery.Create(nil);
  ds.SessionName := session.SessionName;
  ds.DatabaseName := db.Database;
  ds.SQL.Add('Alter database "' + databaseName + '" PATH ''' + newPath + '''');
  ds.ExecSQL;
  FreeAndNil(ds);

  FreeAndNil(db);
end;

end.

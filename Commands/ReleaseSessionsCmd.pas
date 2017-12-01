unit ReleaseSessionsCmd;

interface

procedure ReleaseSessions(databaseName : String;
              userId, password : String;
              hostName : String;
              hostPort : Integer);

implementation
uses
  Classes,
  sysUtils,
  strUtils,

  edbcomps,

  SessionManager;

procedure ReleaseSessions(databaseName : String;
              userId, password : String;
              hostName : String;
              hostPort : Integer);
var
  sessionMgr : TSessionManager;
	db : TEDBDatabase;
	ds : TEDBQuery;

  Sessions : TStringList;
  i: Integer;
begin
	sessionMgr := TSessionManager.Create(userId, password, hostName, hostPort);



  try
      db := TEDBDatabase.Create(nil);
      ds := TEDBQuery.Create(nil);
      Sessions := TStringList.Create;

      try
        db.SessionName := sessionMgr.session.Name;

        // This is extra setup that is needed for Remove Server Session to work.
        db.Session.SessionType := stRemote;

        db.session.LoginUser := userId;
        db.session.LoginPassword := password;
        db.session.CharacterSet := csAnsi;
        if AnsiLeftStr(hostName, 2) = '\\' then
          db.session.RemoteHost := AnsiRightStr(hostName, length(hostName) - 2)
        else
          db.session.RemoteAddress := hostName;
        db.session.RemotePort := hostPort; //12010;

        db.Database := 'Configuration' ; //databaseName;
        db.DatabaseName := databaseName + DateTimeToStr(now);

        ds.SessionName := sessionMgr.session.SessionName;
        ds.DatabaseName := 'Configuration'; // db.Database;
        ds.SQL.Add('Select Distinct SessionId From Configuration.ServerSessionLocks ' +
                   'Where DatabaseName = ''' + databaseName + ''' and ObjectType=''Database''');

        ds.ExecSQL;
        while not ds.EOF do
        begin
          if ds.FieldByName('SessionId').AsInteger <> sessionMgr.session.CurrentRemoteID then
            Sessions.Add(ds.FieldByName('SessionId').AsString);

          ds.Next;
        end;
        ds.Close;

        for i := 0 to Sessions.Count - 1 do
          db.Execute('Remove Server Session ' + Sessions[i]);

      finally
        FreeAndNil(db);
        FreeAndNil(ds);
        FreeAndNil(Sessions);
      end;
  finally
    sessionMgr.Free;

  end;
end;
end.

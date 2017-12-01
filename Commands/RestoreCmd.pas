unit RestoreCmd;

interface

procedure Restore(storeName, fileName : String;
                  promptOnUsingNewest : Boolean; // indicates we want to ask the user to verify the name of the newest backup to use.
                  databaseName : String;
                  userId, password : String;
                  hostName : String;
                  hostPort : Integer);

implementation
uses
  SysUtils,
  DB,

  edbcomps,

  SessionManager,
  ConsoleHelper;

procedure Restore(storeName, fileName : String;
                  promptOnUsingNewest : Boolean; // indicates we want to ask the user to verify the name of the newest backup to use.
                  databaseName : String;
                  userId, password : String;
                  hostName : String;
                  hostPort : Integer);
var
  sessionMgr : TSessionManager;
	db : TEDBDatabase;
	ds : TEDBQuery;
  promptAnswer : String;

  function GetNewestBackup : String;
  begin
    ds.SQL.Clear;
    // This will get the latest backup that is in the backup store.
    ds.SQL.Add('Select Name from Configuration.Backups Order By CreatedOn Desc Range 1 to 1');
    ds.ExecSQL;

    Result := '';
    if not ds.EOF then
      Result := ds.FieldByName('Name').AsString;
  end;

begin
	sessionMgr := TSessionManager.Create(userId, password, hostName, hostPort);
  db := TEDBDatabase.Create(nil);
  ds := TEDBQuery.Create(nil);
  try
    db.OnStatusMessage := sessionMgr.Status;
    db.OnLogMessage := sessionMgr.Status;
	  db.SessionName := sessionMgr.session.Name;
    db.Database := 'Configuration'; // make sure that we are not in the database we are restoring.
    db.LoginPrompt := true;
    db.DatabaseName := databaseName + DateTimeToStr(now);

    ds.SessionName := sessionMgr.session.SessionName;
    ds.DatabaseName := db.Database;
    ds.OnStatusMessage := sessionMgr.Status;
    ds.OnLogMessage := sessionMgr.Status;

//    ds.SQL.Add('Select * from Configuration.Stores');
//    ds.ExecSQL;
//    while not ds.EOF do
//    begin
//      writeln(ds.FieldByName('Name').AsString);
//      ds.Next;
//    end;

    ds.SQL.Add('Set Backups Store to "' + storeName + '"');
    ds.ExecSQL;

    if fileName = '*' then
    begin
      fileName := GetNewestBackup;
      if fileName = '' then
        WritelnError('There were no backups.')
      else
      begin
        if promptOnUsingNewest then
        begin
          Write('The newest backup is called "' + fileName + '". Do you want to use that? (y/n)');
          Readln(promptAnswer);
          if lowercase(promptAnswer) = 'y' then
            WritelnInfo('  Using backup file "' + fileName + '"')
          else
            fileName := '';
        end
        else
          WritelnInfo('  Using backup file "' + fileName + '"')
      end;
    end;

    if fileName <> '' then
    begin
      ds.SQL.Clear;
      ds.SQL.Add('Restore Database "' + databaseName + '" From "' + fileName + '" In Store "' + storeName + '" Include Catalog');
      ds.ExecSQL;
    end;

  finally
    FreeAndNil(db);
    FreeAndNil(sessionMgr);
  end;
end;

end.

unit VerifyRepairCmd;

interface

procedure VerifyRepair(op : String;
							tablename : String;
              startAt : String;
      				databaseName : String;
              userId, password : String;
              hostName : String;
              hostPort : Integer);

implementation
uses
  SysUtils,
  Classes,

  edbcomps,

  SessionManager,
  ConsoleHelper,
  QueryCmd;

procedure VerifyRepair(op : String;
							tablename : String;
              startAt : String;
      				databaseName : String;
              userId, password : String;
              hostName : String;
              hostPort : Integer);
var
  sessionMgr : TSessionManager;
	db : TEDBDatabase;
	ds : TEDBQuery;

  tables : TStringList;
  iTable: Integer;

begin
	if (lowercase(op) <> 'verify') and (lowercase(op) <> 'repair') then
  	raise Exception.Create('bad op');

	sessionMgr := TSessionManager.Create(userId, password, hostName, hostPort);
  tables := TStringList.Create;

  try
    if tableName = '*' then // verify all of the tables
    begin
      db := TEDBDatabase.Create(nil);
      ds := TEDBQuery.Create(nil);

      try
        db.SessionName := sessionMgr.session.Name;
        db.Database := databaseName;
        db.LoginPrompt := true;
        db.DatabaseName := databaseName + DateTimeToStr(now);

        ds.SessionName := sessionMgr.session.SessionName;
        ds.DatabaseName := db.Database;
        ds.SQL.Add('Select Name from information.tables Order By Name');
        ds.ExecSQL;
        while not ds.EOF do
        begin
          if (startAt = '') or (UpperCase(ds.FieldByName('Name').AsString) >= UpperCase(startAt)) then
            tables.Add(ds.FieldByName('Name').AsString);

          ds.Next;
        end;

      finally
        FreeAndNil(db);
        FreeAndNil(ds);
      end;
    end

    else
    begin
      tables.Add(tableName);

    end;

    for iTable := 0 to tables.Count - 1 do
    begin
      WritelnStatus('Performing ' + op + ' on ' + tables[iTable]);

      Query(op + ' TABLE "' + tables[iTable] + '"', 0, databaseName, userId, password, hostName, hostPort, false, 'table', true, '');
    end;

  finally
    FreeAndNil(tables);

  end;

end;


end.

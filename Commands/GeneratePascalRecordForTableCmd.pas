unit GeneratePascalRecordForTableCmd;

interface
procedure GeneratePascalRecordForTable(
              tableName : string;
              className : String;
      				databaseName : String;
              userId, password : String;
              hostName : String;
              hostPort : Integer);

implementation
uses
  SysUtils,
  db,

  edbcomps,

  SessionManager;

procedure GeneratePascalRecordForTable(
              tableName : string;
              className : String;
      				databaseName : String;
              userId, password : String;
              hostName : String;
              hostPort : Integer);
var
	db : TEDBDatabase;
  sessionMgr : TSessionManager;
	ds : TEDBQuery;

  sSQL : String;

  outStr : String;

  fieldName,
  fieldType : String;

  tmpClassName : String;

begin
  sessionMgr := TSessionManager.Create(userId, password, hostName, hostPort);

  db := TEDBDatabase.Create(nil);
  db.OnStatusMessage := sessionMgr.Status;
  db.OnLogMessage := sessionMgr.Status;

  db.SessionName := sessionMgr.session.Name;
  db.Database := databaseName;
  db.LoginPrompt := true;
  db.DatabaseName := databaseName + DateTimeToStr(now);

  ds := TEDBQuery.Create(nil);
  ds.SessionName := sessionMgr.session.SessionName;
  ds.DatabaseName := db.Database;

  sSQL := 'Select Tables.Name TableName, '
             + 'c.Name FieldName, c.Description, c.Type, '
             + 'c.Length, c.Precision, c.Scale, '
             + 'c.Generated, c.Identity '
             + ' From Information.Tables t inner join Information.TableColumns c on t.Name = c.TableName ';
  if tableName <> '*' then
    sSQL := sSQL + 'Where t.Name = ''' + tableName + ''' ';

  sSQL := sSQL + 'Order by t.Name, c.OrdinalPos';

  ds.SQL.Add(sSQL);
  ds.ExecSQL;



  // Field Names
  while not ds.Eof do
  begin
    tableName := ds.FieldByName('TableName').AsString;

    if className = '' then
      tmpClassName := tableName
    else
      tmpClassName := className;

    outStr := 'Unit ' + tmpClassName + 'Type;' + CRLF
              + 'interface' + CRLF
              + 'uses Contnrs;' + CRLF
              + 'Type' + CRLF
              + CRLF
              ;
    Writeln(outStr);

    outStr := '';
    repeat
//      if outStr <> '' then
//        outStr := outStr + ';' + CRLF;

      if (Not ds.FieldByName('Generated').AsBoolean) or (ds.FieldByName('Identity').AsBoolean) then // skip generated, but not Identity
      begin
        fieldName := ds.FieldByName('FieldName').AsString;
        fieldType := LowerCase(ds.FieldByName('Type').AsString);

        if (fieldType = 'integer') or (fieldType = 'smallint') then
          fieldType := 'Integer'

        else if (fieldType = 'timestamp') or (fieldType = 'date') then
          fieldType := 'TDateTime'

        else if fieldType = 'boolean' then
          fieldType := 'Boolean'

        else if fieldType = 'clob' then
          fieldType := 'String'

        else if fieldType = 'varchar' then
          fieldType := 'String'

        else if fieldType = 'char' then
          fieldType := 'String'

        else if (fieldType = 'decimal') or (fieldType='float') then
          fieldType := 'Double'

        else
          fieldType := 'String';

        outStr := outStr + Format('  %s : %s; %s', [fieldName, fieldType, CRLF]);
      end;

      ds.Next;

    until ds.Eof or (tableName <> ds.FieldByName('TableName').AsString);

    outStr := 'T' + tmpClassName + ' = class' + CRLF
              + outStr
              + 'End;' + CRLF
              + CRLF
              ;

    Writeln(outStr);

    outStr := 'T' + tmpClassName + 'List = class(TObjectList) ' + CRLF
              + '  protected' + CRLF
              + '    function GetItem(Index: Integer): T' + tmpClassName + ';' + CRLF
              + '  public'  + CRLF
              + '    procedure Add(info : T' + tmpClassName + ');' + CRLF
              + '    property Items[Index: Integer]: T' + tmpClassName + ' read GetItem; default; ' + CRLF
              + 'end;' + CRLF;

    outStr := outStr  + 'Implementation' + CRLF
              + CRLF;

    outStr := outStr + 'procedure T' + tmpClassName + 'List.Add(info: T' + tmpClassName + ');' + CRLF
              + 'begin' + CRLF
              + '  inherited Add(info);' + CRLF
              + 'end;' + CRLF
              + '' + CRLF
              + 'function T' + tmpClassName + 'List.GetItem(Index: Integer): T' + tmpClassName + ';' + CRLF
              + 'begin' + CRLF
              + '  Result := T' + tmpClassName + '(inherited GetItem(Index));' + CRLF
              + 'end;' + CRLF
              ;

    outStr := outStr + CRLF
              + 'end.';
    Writeln(outStr);
    Writeln;
  end;

  FreeAndNil(ds);
  FreeAndNil(db);

end;

end.

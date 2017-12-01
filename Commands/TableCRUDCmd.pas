unit TableCRUDCmd;

interface
procedure TableCRUD(tablename : String;
              maxStringLength : Integer;
              className : String;
      				databaseName : String;
              userId, password : String;
              hostName : String;
              hostPort : Integer);

implementation
uses
  sysUtils,
  strUtils,
  db,

  edbcomps,

  SessionManager;

// TODO: Reimplement as mustache template
// Generates
//    Select Statement
//    Insert Statement skeleton
//    Update Statement skeleton
procedure TableCRUD(tablename : String;
              maxStringLength : Integer;
              className : String;
      				databaseName : String;
              userId, password : String;
              hostName : String;
              hostPort : Integer);
var
	db : TEDBDatabase;
  sessionMgr : TSessionManager;

	ds : TEDBQuery;

  sName : String;

  outStr : String;
  valuesStr : String;
  undecoratedClassName,
  tmpClassName,
  tmpDBClassName : String;

  function MakeAsString(ft : TFieldType) : String;
  begin
    case ft of
      ftUnknown, ftString, ftMemo : Result := 'String';
      ftSmallint, ftInteger, ftWord, ftLargeint : Result := 'Integer';
      ftBoolean : Result := 'Boolean';
      ftFloat : Result := 'Float';
      ftCurrency, ftBCD : Result := 'Currency';
      ftDate, ftTime, ftDateTime : Result := 'DateTime';
      else
        Result := 'String' + IntToStr(Integer(ft));
    end;
  end;


  function MakeSelectString(indentSpaces : Integer) : String;
  var
    outStr : String;
    iField : Integer;
    indent : String;
  begin
    indent := DupeString(' ', indentSpaces);

  	// Select Statement
    outStr := indent + 'sql := ''Select '' ' + #13#10;
    for iField := 0 to ds.Fields.Count - 1 do
    begin
      sName := ds.Fields[iField].FieldName;
    	if iField <> 0 then
      	outStr := outStr + ', ''' + #13#10;

      outStr := outStr + indent + '       + ''' + sName;
    end;
    outStr := outStr + indent + '''' + #13#10 + indent + '       + '' From "' + tablename + '"'';';

    Result := outStr;
  end;

  function MakeInsertString(indentSpaces : Integer; skipID : Boolean) : string;
  var
    outStr : String;
    iField : Integer;
    firstField : Boolean;
    indent : String;
  begin
    indent := DupeString(' ', indentSpaces);

    outStr := indent + 'sql := ''Insert Into "' + tablename + '"(''' + #13#10;
    valuesStr := '';
    firstField := true;

    for iField := 0 to ds.Fields.Count - 1 do
    begin
      sName := ds.Fields[iField].FieldName;
      if ((skipID) and (LowerCase(sName) <> 'id')) or (not skipID)  then
      begin
        if not firstField then
          outStr := outStr + ', ''' + #13#10;

        outStr := outStr + indent + '       + ''' + sName;

        if valuesStr <> '' then
          valuesStr := valuesStr + ', ''' + #13#10
        else
          valuesStr := #13#10;

        valuesStr := valuesStr + indent + '       + ''      :' + sName;

        firstField := false;
      end;
    end;
    outStr := outStr + indent + ')''' + #13#10 + indent + '       + ''Values(''' + valuesStr + ') '';';

    Result := outStr;
  end;

  function MakeUpdateString(indentSpaces : Integer; skipId : Boolean) : string;
  var
    outStr : String;
    iField : Integer;
    indent : String;
    firstField : Boolean;
  begin
    indent := DupeString(' ', indentSpaces);

  	// Update Statement
    outStr := indent + 'sql := ''Update "' + tablename + '"''' + #13#10;
    firstField := True;

    for iField := 0 to ds.Fields.Count - 1 do
    begin
      sName := ds.Fields[iField].FieldName;
      if (not skipID) or ((LowerCase(sName) <> 'id') and skipID) then
      begin
        if firstField then
          outStr := outStr + indent + '       + ''Set ''' + #13#10
        else
          outStr := outStr + ', ''' + #13#10;

        outStr := outStr + indent +   '       + ''' + sName + ' = :' + sName;

        firstField := false;
      end;
    end;
    outStr := outStr + '''' + #13#10 + indent + '       + '' Where id=:ID'';' + CRLF;

    Result := outStr;
  end;

  function MakeSetParams(indentSpaces : Integer; skipSetId : Boolean; skipReadNewID : Boolean) : String;
  var
    outStr : String;
    iField : Integer;
    indent : String;
  begin
    indent := DupeString(' ', indentSpaces);

    // Output code for handling parameters.
    outStr := indent + 'dq := db.Prepare(sql);' + #13#10;
    for iField := 0 to ds.Fields.Count - 1 do
    begin
      sName := ds.Fields[iField].FieldName;
      if (not skipSetId) or ((LowerCase(sName) <> 'id') and skipSetId) then
      begin
        outStr := outStr + indent + 'dq.ParamByName(''' + sName + ''').As';
        outStr := outStr + MakeAsString(ds.Fields[iField].DataType);
        outStr := outStr + ' := item.' + sName + ';' + #13#10;
      end;
    end;
    outStr := outStr + indent + 'dq.ExecSQL;' + #13#10;

    // for updates, we don't care if we do this.
    if Not skipReadNewID then
      outStr := outStr + indent + 'item.ID := dq.ParamByName(''id'').AsInteger;' + #13#10 + CRLF;

    Result := outStr;
  end;

  function MakeReadFields(indentSpaces : Integer) : String;
  var
    outStr : String;
    iField : Integer;
    indent : String;
  begin
    indent := DupeString(' ', indentSpaces);

    // Code for assigning from a result set.
    outStr := indent + 'item := ' + tmpClassName + '.Create;' + #13#10;
    for iField := 0 to ds.Fields.Count - 1 do
    begin
      sName := ds.Fields[iField].FieldName;
      outStr := outStr + indent + 'item.' + sName + ' := ds.FieldByName(''' + sName + ''').As';

      outStr := outStr + MakeAsString(ds.Fields[iField].DataType);

      outStr := outStr + ';' + #13#10;
    end;

    Result := outStr;
  end;

begin
	sessionMgr := TSessionManager.Create(userId, password, hostName, hostPort);

  db := TEDBDatabase.Create(nil);

  if className = '' then
    undecoratedClassName := tablename
  else
    undecoratedClassName := className;

  tmpClassName := 'T' + undecoratedClassName;

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

  ds.SQL.Add('Select * From "' + tablename + '" Range 0 to 0');
  ds.ExecSQL;

  // Field Names
  if ds.Fields.Count > 0 then
  begin
    outStr := 'Unit ' + undecoratedClassName + 'DB;' + CRLF
              + 'Interface' + CRLF
              + 'Uses' + CRLF
              + '  DB,' + CRLF
              + '  DBClass2,' + CRLF
              + '  ' + undecoratedClassName + 'Type // autogenerated unit with type info' + CRLF
              + '  ;' + CRLF
              + CRLF
              + 'Type' + CRLF
              + CRLF
              ;


    tmpDBClassName := tmpClassName + 'Table';
    outStr := outStr + tmpDBClassName + ' = class' + CRLF
              + 'private' + CRLF
              + '  function MakeItemFromDS(ds : TDataset) : ' + tmpClassName + ';' + CRLF
              + 'public' + CRLF
              + '  procedure Add(item : ' + tmpClassName + ');' + CRLF
              + '  function Read(id : integer) : ' + tmpClassName + ';' + CRLF
              + '  procedure Update(item: ' + tmpClassName + ');' + CRLF
              + '  procedure Save(item: ' + tmpClassName + ');' + CRLF
              + '  procedure Delete(id : integer); overload;' + CRLF
              + '  procedure Delete(ids : idArray); overload;' + CRLF
              + '  function List() : ' + tmpClassName + 'List; // add any parameters for filtering, ordering' + CRLF
              ;

    outStr := outStr + 'end; //' + tmpDBClassName + CRLF;

    Writeln(outStr);

    Writeln('// ========= ' + tmpDBClassName + ' ==========');

    outStr := 'Implementation' + CRLF
              + 'uses' + CRLF
              + '  SysUtils,' + CRLF
              + '  edbcomps,' + CRLF
              + '  LodgicalDBClass' + CRLF
              + '  ;' + CRLF
              + CRLF;

    outStr := outStr + '// Factory for items in the database.' + CRLF
              + 'function ' + tmpDBClassName + '.MakeItemFromDS(ds : TDataset) : ' + tmpClassName + ';' + CRLF
              + 'var' + CRLF
              + '  item : ' + tmpClassName + ';' + CRLF
              + 'begin' + CRLF
              + MakeReadFields(2)
              + '  Result := item;' + CRLF
              + 'end;' + CRLF + CRLF;

    outStr := outStr + 'procedure ' + tmpDBClassName + '.Add(item : ' + tmpClassName + ');' + CRLF
              + 'var' + CRLF
              + '  db : TBLISDatabase_Elevate;' + CRLF
              + '  dq   : TEDBQuery;' + CRLF
              + '  sql : String;' + CRLF
              + 'begin' + CRLF
              + '  db := TBLISDatabase_Elevate(CreateDatabaseObject);' + CRLF
              + '  dq := nil;' + CRLF
              + '  try' + CRLF
              + MakeInsertString(4, false) + CRLF
              + MakeSetParams(4, true, false) + CRLF
              + '  finally' + CRLF
              + '    if Assigned(dq) then' + CRLF
              + '      FreeAndNil(dq);' + CRLF
              + '' + CRLF
              + '    FreeAndNil(db);' + CRLF
              + '  end;' + CRLF
              + 'end;' + CRLF
              + '' + CRLF
              ;

    outStr := outStr + 'function ' + tmpDBClassName + '.Read(id : Integer) : ' + tmpClassName + ';' + CRLF
              + 'var' + CRLF
              + '  sql : String;' + CRLF
              + '  ds  : TDataset;' + CRLF
              + '  db : TBlisDatabase;' + CRLF
              + 'begin' + CRLF
              + '  db := CreateDatabaseObject;' + CRLF
              + '  ds := nil;' + CRLF
              + '  try' + CRLF
              + MakeSelectString(4) + CRLF
              + '    sql := sql + '' Where ID = '' + IntToStr(id); // filter by ID' + CRLF
              + '    ds := db.GetData(sql);' + CRLF
              + '    if not ds.EOF then' + CRLF
              + '    begin' + CRLF
              + '      Result := MakeItemFromDS(ds);' + CRLF
              + '    end' + CRLF
              + '' + CRLF
              + '    else' + CRLF
              + '      Result := nil;' + CRLF
              + '' + CRLF
              + '    ds.Close;' + CRLF
              + '' + CRLF
              + '  finally' + CRLF
              + '    FreeAndNil(db);' + CRLF
              + '    if Assigned(ds) then' + CRLF
              + '      FreeAndNil(ds);' + CRLF
              + '  end;' + CRLF
              + 'end;' + CRLF
              + CRLF;

    outStr := outStr + 'procedure ' + tmpDBClassName + '.Update(item: ' + tmpClassName + ');' + CRLF
              + 'var' + CRLF
              + '  sql : String;' + CRLF
              + '  db : TBLISDatabase_Elevate;' + CRLF
              + '  dq : TEDBQuery;' + CRLF
              + '' + CRLF
              + 'begin' + CRLF
              + '  dq := nil;' + CRLF
              + '  db := TBLISDatabase_Elevate(CreateDatabaseObject);' + CRLF
              + '  try' + CRLF
              + MakeUpdateString(4, true) + CRLF
              + MakeSetParams(4, false, true) + CRLF
              + '' + CRLF
              + '    db.Execute(sql);' + CRLF
              + '' + CRLF
              + '  finally' + CRLF
              + '    FreeAndNil(db);' + CRLF
              + '    if Assigned(dq) then' + CRLF
              + '      FreeAndNil(dq);' + CRLF
              + '  end;' + CRLF
              + 'end;' + CRLF
              + CRLF
              ;

    outStr := outStr + 'procedure ' + tmpDBClassName + '.Save(item: ' + tmpClassName + ');' + CRLF
              + 'begin' + CRLF
              + '	if item.ID = 0 then' + CRLF
              + '  	Add(item)' + CRLF
              + '' + CRLF
              + '  else' + CRLF
              + '  	Update(item);' + CRLF
              + 'end;' + CRLF
              + CRLF;

    outStr := outStr + 'procedure ' + tmpDBClassName + '.Delete(id: Integer);' + CRLF
              + 'var' + CRLF
              + '	 sql : String;' + CRLF
              + '  db : TBlisDatabase;' + CRLF
              + 'begin' + CRLF
              + '  db := CreateDatabaseObject;' + CRLF
              + '  try' + CRLF
              + '    sql := ''Delete from "' + tablename + '" Where ID = '' + IntToStr(id);' + CRLF
              + '' + CRLF
              + '    db.Execute(sql);' + CRLF
              + '' + CRLF
              + '  finally' + CRLF
              + '    FreeAndNil(db);' + CRLF
              + '' + CRLF
              + '  end;' + CRLF
              + 'end;' + CRLF + CRLF
              ;

    outStr := outStr + 'procedure ' + tmpDBClassName + '.Delete(ids: idArray);' + CRLF
              + 'var' + CRLF
              + '  sql : String;' + CRLF
              + '  db : TBlisDatabase;' + CRLF
              + '  sIDs : string;' + CRLF
              + '  i: Integer;' + CRLF
              + 'begin' + CRLF
              + '  for i := Low(ids) to High(ids) do' + CRLF
              + '  begin' + CRLF
              + '    if sIDs <> '''' then' + CRLF
              + '      sIDs := sIDs + '','';' + CRLF
              + '    sIDs := sIDs + IntToStr(ids[i]);' + CRLF
              + '  end;' + CRLF
              + CRLF
              + '  db := CreateDatabaseObject;' + CRLF
              + '  try' + CRLF
              + '    sql := ''Delete from "' + tablename + '" Where ID In ('' + sIDs + '')'';' + CRLF
              + '' + CRLF
              + '    db.Execute(sql);' + CRLF
              + '' + CRLF
              + '  finally' + CRLF
              + '    FreeAndNil(db);' + CRLF
              + '' + CRLF
              + '  end;' + CRLF
              + 'end;' + CRLF + CRLF
              ;



    outStr := outStr + 'function ' + tmpDBClassName + '.List() : ' + tmpClassName + 'List; // add any parameters for filtering, ordering' + CRLF
              + 'var' + CRLF
              + '  sql : String;' + CRLF
              + '  ds  : TDataset;' + CRLF
              + '  db : TBlisDatabase;' + CRLF
              + 'begin' + CRLF
              + '  db := CreateDatabaseObject;' + CRLF
              + '  ds := nil;' + CRLF
              + MakeSelectString(2) + CRLF
              + '// add where/order clauses as necessary' + CRLF
              + '  try' + CRLF
              + '    ds := db.GetData(sql);' + CRLF
              + '    Result := ' + tmpClassName + 'List.Create;' + CRLF
              + '    while not ds.EOF do' + CRLF
              + '    begin' + CRLF
              + '      Result.Add(MakeItemFromDS(ds));' + CRLF
              + '      ds.Next;' + CRLF
              + '    end;' + CRLF
              + '' + CRLF
              + '    ds.Close;' + CRLF
              + '' + CRLF
              + '  finally' + CRLF
              + '    FreeAndNil(db);' + CRLF
              + '    if Assigned(ds) then' + CRLF
              + '      FreeAndNil(ds);' + CRLF
              + '  end;' + CRLF
              + 'end;' + CRLF;

    outStr := outStr + CRLF
              + 'end.';

    Writeln(outStr);

  end; // if fields.count > 0

  FreeAndNil(ds);
  FreeAndNil(db);
  FreeAndNil(sessionMgr);

end;


end.

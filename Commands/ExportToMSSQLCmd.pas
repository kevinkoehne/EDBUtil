unit ExportToMSSQLCmd;

interface

procedure ExportToMSSQL(tableName,
                        databaseName : String;
                        userId, password : String;
                        hostName : String;
                        hostPort : Integer);

implementation
uses
  SysUtils,
  StrUtils,

  edbcomps,

  SessionManager;

procedure ExportToMSSQL(tableName,
                        databaseName : String;
                        userId, password : String;
                        hostName : String;
                        hostPort : Integer);
var
	db : TEDBDatabase;
  sessionMgr : TSessionManager;
	ds,
  dsConstraints : TEDBQuery;

  sSQL : String;

  outStr : String;

  fieldName,
  fieldType : String;

  defaultExpr,
  defaultStr,
  nullableStr : String;

  function MakeIndexes(tableName : String) : String;
  var
    sSQL : String;
    dsIndexes : TEDBQuery;
    lastIndex : String;
    indexName : String;
    iIndex : Integer;
    iCol : Integer;
  begin
    Result := '';

    sSQL := 'Select  t.Name IndexName, c.ColumnName, c.Descending '
            + 'from Information.Indexes t '
            + 'inner join Information.IndexColumns c on t.TableName = c.TableName and t.Name = c.IndexName '
            + 'Where t.Type Not In (''Primary Key'', ''Text Index'') and t.TableName = ''' + tableName + ''' '
            + 'Order By t.TableName, t.Name, c.OrdinalPos ';

    dsIndexes := TEDBQuery.Create(nil);
    try
      dsIndexes.SessionName := sessionMgr.session.SessionName;
      dsIndexes.DatabaseName := db.Database;

      dsIndexes.SQL.Add(sSQL);
      dsIndexes.ExecSQL;

      lastIndex := '';
      iIndex := 0;
      iCol := 0;
      while not dsIndexes.EOF do
      begin
        if lastIndex <> dsIndexes.FieldByName('IndexName').AsString then
        begin
          if lastIndex <> '' then
            Result := Result + ');' + CRLF;

          indexName := 'idx' + tableName + IntToStr(iIndex);
          Result := Result + 'CREATE NONCLUSTERED INDEX [' + indexName + '] ON [dbo].[' + tableName + '] (' + CRLF;
          lastIndex := dsIndexes.FieldByName('IndexName').AsString;
          iCol := 0;
          iIndex := iIndex + 1;
        end;

        if iCol <> 0 then
          Result := Result + ',';

        Result := Result + '[' + dsIndexes.FieldByName('ColumnName').AsString + ']';
        if dsIndexes.FieldByName('Descending').AsBoolean then
          Result := Result + ' DESC';
        Result := Result + CRLF;

        iCol := iCol + 1;
        dsIndexes.Next;
      end;
      if lastIndex <> '' then
        Result := Result + ');' + CRLF;

    finally
      FreeAndNil(dsIndexes);
    end;

  end;

  procedure LoadContraints(var dsContraints : TEDBQuery);
  begin
    if Assigned(dsContraints) then
      FreeAndNil(dsContraints);

    sSQL := 'Select  t.Name IndexName, t.TableName, t.Type, c.ColumnName, c.Descending '
            + 'from Information.Indexes t '
            + 'inner join Information.IndexColumns c on t.TableName = c.TableName and t.Name = c.IndexName '
            + 'Where t.Type = ''Primary Key'' and t.TableName = ''' + tableName + ''' '
            + 'Order By t.TableName, t.Name, c.OrdinalPos ';

    dsContraints := TEDBQuery.Create(nil);
    dsContraints.SessionName := sessionMgr.session.SessionName;
    dsContraints.DatabaseName := db.Database;

    dsContraints.SQL.Add(sSQL);
    dsContraints.ExecSQL;
  end;

  function MakeConstraints(dsContraints : TEDBQuery; tableName : String) : String;
  var
    sFields : String;
  begin

    Result := '';
    dsConstraints.First;

    if not dsContraints.eof then
    begin
      sFields := '';
      while not dsContraints.Eof do
      begin
        if sFields <> '' then
          sFields := sFields + ',' + crlf;

        sFields := sFields + dsContraints.FieldByName('ColumnName').AsString;
        if dsContraints.FieldByName('Descending').AsBoolean then
          sFields := sFields + ' DESC';

        dsContraints.Next;
      end;
      Result := Format(', CONSTRAINT [PK_%s] PRIMARY KEY CLUSTERED (%s) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]', [tableName, sFields]);
    end;
  end;

  function FieldInConstraint(dsConstraints : TEDBQuery; tableName, fieldName : String) : Boolean;
  begin
    Result := false;
    dsConstraints.First;
    while not dsConstraints.Eof do
    begin
      if fieldName = dsConstraints.FieldByName('ColumnName').AsString then
      begin
        Result := True;
        break;
      end;

      dsConstraints.Next;
    end;

  end;
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
             + 'c.Nullable, '
             + 'c.Generated, '
             + 'c.GeneratedWhen, '
             + 'c.GenerateExpr, '
             + 'c.Identity, '
             + 'c.IdentityIncrement, '
             + 'c.IdentitySeed, '
             + 'c.DefaultExpr '
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

    LoadContraints(dsConstraints);

    outStr := '';
    repeat
      if outStr <> '' then
        outStr := outStr + ',' + CRLF;

      defaultStr := '';
      defaultExpr := Trim(ds.FieldByName('DefaultExpr').AsString);

      fieldName := ds.FieldByName('FieldName').AsString;
      fieldType := LowerCase(ds.FieldByName('Type').AsString);

      nullableStr := 'NULL';
      if Not ds.FieldByName('Nullable').AsBoolean then
        nullableStr := 'NOT NULL'
      else
      begin
        if FieldInConstraint(dsConstraints, tableName, fieldName) then
          nullableStr := 'NOT NULL';
      end;

      if fieldType = 'integer' then
      begin
        fieldType := 'int';
        if ds.FieldByName('Identity').AsBoolean then
        begin
          fieldType := fieldType + Format(' Identity (%d, %d)', [ds.FieldByName('IdentitySeed').AsInteger, ds.FieldByName('IdentityIncrement').AsInteger]);
          nullableStr := 'NOT NULL'; // override the nullable'ness.
        end;
      end

      else if fieldType = 'timestamp' then
      begin
        fieldType := 'datetime';
        if ds.FieldByName('Generated').AsBoolean then // really should be default
        begin
          if StartsText('CURRENT_TIMESTAMP', UpperCase(ds.FieldByName('GenerateExpr').AsString))  then
            defaultExpr := 'getdate()';
        end
        else if StartsText('CURRENT_TIMESTAMP', UpperCase(defaultExpr)) then
        begin
          defaultExpr := 'getdate()';
        end;


      end

      else if fieldType = 'boolean' then
      begin
        fieldType := 'bit';
        if defaultExpr <> '' then
        begin
          if LowerCase(defaultExpr) = 'false' then
            defaultExpr := '0'
          else if LowerCase(defaultExpr) = 'true' then
            defaultExpr := '1';
        end;

      end

      else if fieldType = 'clob' then
      begin
        fieldType := 'text';
      end

      else if fieldType = 'varchar' then
        fieldType := 'varchar(' + ds.FieldByName('Length').AsString + ')'

      else if fieldType = 'char' then
        fieldType := 'char(' + ds.FieldByName('Length').AsString + ')'

      else if fieldType = 'decimal' then
        fieldType := 'decimal(' + ds.FieldByName('Precision').AsString + ',' + ds.FieldByName('Scale').AsString + ')'

      ;

      if defaultExpr <> '' then
        defaultStr := Format('DEFAULT (%s)', [defaultExpr]);


      outStr := outStr + Format('[%s] %s %s %s', [fieldName, fieldType, nullableStr, defaultStr]);

      ds.Next;

    until ds.Eof or (tableName <> ds.FieldByName('TableName').AsString);

    outStr := 'IF OBJECT_ID (N''' + tableName + ''', N''U'') IS NOT NULL ' + CRLF
              + ' Drop Table [' + tableName + '];' + CRLF
              + 'Create Table [' + tableName + '] (' + CRLF
              + outStr
              + MakeConstraints(dsConstraints, tableName) + ');';

    Writeln(outStr);

    Writeln(MakeIndexes(tableName));

    Writeln; Writeln;

  end;

  FreeAndNil(ds);
  FreeAndNil(db);

end;


end.

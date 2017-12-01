unit ImportCSVCmd;

interface

procedure ImportCSV(tableName : string;
                    inputFile : string;
                    inputFileHasHeader : Boolean;
                    map : String;
                    operation : string; // append or overwrite
                    disableTriggers : Boolean;
                    dateFormat : string; // made up of yyyy, yy, mm, dd
                    trueValue  : String; // the value that translates to TRUE in the CSV data. All else is false.
                    truncateStrings: Boolean;
                    databaseName : String;
                    userId, password : String;
                    hostName : String;
                    hostPort : Integer);

implementation
uses
  Variants,
  Classes,
  SysUtils,
  StrUtils,
  DB,
  Windows,

  edbcomps,

  SessionManager,
  ConsoleHelper;

type
  TStringArray = array of String;

Function ParseCSV( TempString : String;
//                   Field : Integer;
                   var StringArray : TStringArray;
                   delimStringField : String = '"'): String;
Var
  Count : Integer;
  Done : Boolean;
  Data : String;
  CH : Char;
Begin
  Data := '';
  TempString := Trim(TempString);
  if Length(TempString) > 0 then
  Begin
    Count := 0;
//    While (Count < Field) Do
    while(TempString <> '') do
    Begin
      Data := '';
      Inc(Count);
      { If First var is a " then the end deliminater will be a " }
      if Length(TempString) > 0 then
      Begin
        SetLength(StringArray, Count);

        if ((TempString[1] = delimStringField)) then
        Begin
          Delete(TempString,1,1);
          Done := False;
          Repeat
            if (Length(TempString) > 0) then
            Begin
              CH := Char(TempString[1]);
              While(CH <> delimStringField) do
              Begin
                Data := Data + TempString[1];
                Delete(TempString,1,1);
                CH := Char(TempString[1]);
              end;
              if ((TempString[1] = delimStringField)) then
              Begin
                if Length(TempString) > 2 then
                Begin
                  if TempString[2] = ',' then
                  Begin
                    Delete(TempString,1,2);
                    Done := True
                  end
                  else
                  Begin
                    Data := Data + TempString[1];
                    Delete(TempString,1,1);
                  end;
                end
                else
                Begin
                  Delete(TempString,1,1);
                  Done := True;
                end;
              end;
            End
            else
              Done := True;
          until Done;
        end
        else { Is A Number }
        Begin
          While((Length(TempString) > 0) and
                (TempString[1] <> ',')) Do
          Begin
            Data := Data + TempString[1];
            Delete(TempString,1,1);
          end;
          { dump the , }
          if Length(TempString) > 0 then
            Delete(TempString,1,1);
        end;
      end;
      TempString := Trim(TempString);

      StringArray[Count - 1] := Data;
    end;
  end;
  ParseCSV := Data;
end;

procedure ImportCSV(tableName : string;
                    inputFile : string;
                    inputFileHasHeader : Boolean;
                    map : String;
                    operation : string; // append or overwrite
                    disableTriggers : Boolean;
                    dateFormat : string; // made up of yyyy, yy, mm, dd
                    trueValue  : String; // the value that translates to TRUE in the CSV data. All else is false.
                    truncateStrings: Boolean;
                    databaseName : String;
                    userId, password : String;
                    hostName : String;
                    hostPort : Integer);
type
  TMap = record
    fieldName : String;
    CSVOffset : Integer;
    MaxLength: Integer;
  end;

var
  sessionMgr : TSessionManager;
	db : TEDBDatabase;
  session : TEDBSession;
	ds : TEDBQuery;

  dsForTypes : TEDBQuery;
  dqInsert : TEDBQuery;
  dqFindEmail : TEDBQuery;
  dqInsertEmail : TEDBQuery;

  mappings : array of TMap;

  fInput : TextFile;
  lineCount : Integer;
  errorCount : Integer;

  csvLine : String;

  iMap : Integer;
  iMapMax:integer;
  sql : String;

  sCSVValue : String;

  tStart : DWORD;

  items : TStringArray;
  iOffset, iMaxLen, iEmailOffset: Integer;
  fieldName : String;
  today : TDateTime;

  procedure ParseMap(sMap : String);
  var
    sl : TStringList;
    iMap: Integer;

    slItem : TStringList;
  begin

    try
      sl := TStringList.Create;
      sl.Delimiter := ';';
      sl.StrictDelimiter := true;
      sl.DelimitedText := sMap;
    except on E:Exception do
      begin
        writeln(E.Message);
        Exit;
      end;
    end;


    SetLength(mappings, sl.Count);

    try
      slItem := TStringList.Create;
      slItem.Delimiter := '=';
      slItem.StrictDelimiter := True;
    except on E:Exception do
      begin
        writeln(E.Message);
        Exit;
      end;
    end;


    for iMap := 0 to sl.Count - 1 do
    begin
      slItem.DelimitedText := sl[iMap];
      if slItem.Count = 2 then
      begin
        mappings[iMap].fieldName := slItem[0];
        if not TryStrToInt(slItem[1], mappings[iMap].CSVOffset) then
          raise Exception.CreateFmt('Invalid column offset in map: %s', [sl[iMap]]);

      end
      else
        raise Exception.CreateFmt('Invalid map: %s', [sl[iMap]]);
    end;

  end;

  procedure AddMaxLengths(tableName: String);
  var
   sessionMgr :TSessionManager;
   dsForTypesLength : TEDBQuery;
   i:integer;
   sql:string;

  begin
    sessionMgr := TSessionManager.Create(userId, password, hostName, hostPort);
    for i:=0 to Length(mappings) -1 do
      begin
        if mappings[i].fieldName <> 'Email' then
          begin
            try
              dsForTypesLength := TEDBQuery.Create(nil);
              dsForTypesLength.SessionName := sessionMgr.session.SessionName;
              dsForTypesLength.DatabaseName := db.Database;
              sql:=Format('Select "Length" from information.tableColumns where tableName=''%s'' and Name=''%s''', [tableName,mappings[i].fieldName ]);

              VerboseWrite(sql);

              dsForTypesLength.SQL.Add(sql); // GetField Length
              dsForTypesLength.ExecSQL;
              mappings[i].MaxLength :=  -1;
               while not dsForTypesLength.EOF do
                begin
                  mappings[i].MaxLength := dsForTypesLength.FieldByName('Length').AsInteger;
                  dsForTypesLength.Next;
                end;
            finally
               FreeAndNil(dsForTypesLength);
            end;
          end;

      end;
  end;
begin

  operation := UpperCase(operation);
  if (operation <> 'APPEND') and (operation <> 'OVERWRITE') then
    raise Exception.CreateFmt('Invalid operation "%s". Only APPEND and OVERWRITE are valid', [operation]);

  VerboseWrite('Operation: ' + operation);

  //try session mgr start
  sessionMgr := TSessionManager.Create(userId, password, hostName, hostPort);

  db := TEDBDatabase.Create(nil);

  //sessionmgr add lines
  db.OnStatusMessage := sessionMgr.Status;
  db.OnLogMessage := sessionMgr.Status;

  db.SessionName := sessionMgr.session.Name;
  db.Database := databaseName;
  db.LoginPrompt := true;
  db.DatabaseName := databaseName + DateTimeToStr(now);

  dsForTypes := TEDBQuery.Create(nil);
  dsForTypes.SessionName := sessionMgr.session.SessionName;
  dsForTypes.DatabaseName := db.Database;
  dsForTypes.SQL.Add(Format('Select * from "%s" Range 0 to 0', [tableName])); // hack to get field type defs.

  dqInsert := TEDBQuery.Create(nil);
  dqInsert.SessionName := sessionMgr.session.SessionName;
  dqInsert.DatabaseName := db.Database;

  dqFindEmail := TEDBQuery.Create(nil);
  dqFindEmail.SessionName := sessionMgr.session.SessionName;
  dqFindEmail.DatabaseName := db.Database;

  dqInsertEmail := TEDBQuery.Create(nil);
  dqInsertEmail.SessionName := sessionMgr.session.SessionName;
  dqInsertEmail.DatabaseName := db.Database;

  ds := TEDBQuery.Create(nil);
  ds.SessionName := sessionMgr.session.SessionName;
  ds.DatabaseName := db.Database;
  dsForTypes.ExecSQL;

  ParseMap(map);
  AddMaxLengths(tableName);

  if disableTriggers then
  begin
    sql := Format('Disable Triggers on "%s"', [tableName]);
    VerboseWrite(sql);

    ds.SQL.Add(sql);
    ds.ExecSQL;
    ds.SQL.Clear;
  end;

  try
    // Delete ALL of the data.
    if operation = 'OVERWRITE' then
    begin
      sql := Format('Empty Table "%s"', [tableName]);
      VerboseWrite(sql);
      ds.SQL.Add(sql);
      ds.ExecSQL;
      ds.SQL.Clear;
    end;

    iMapMax:= High(mappings);

    // Create the prepared statement.
    sql := Format('Insert Into "%s" (', [tableName]);
    for iMap := Low(mappings) to iMapMax do
    begin
      sql := sql + mappings[iMap].fieldName;
      if (iMap < iMapMax) then
        sql := sql + ','
    end;

    sql := sql + ') Values (' + #13#10;

    for iMap := Low(mappings) to iMapMax do
    begin
      sql := sql + ':' + mappings[iMap].fieldName;
      if (iMap < iMapMax) then
        sql := sql + ','
    end;
    sql := sql + ')' + #13#10;

    VerboseWrite( sql);

    dqInsert.SQL.Add(sql);
    dqInsert.Prepare;

    // Create the lookup for email
    sql := 'Select ID from tblEmail Where emailAddress = :email';
    dqFindEmail.SQL.Add(sql);
    dqFindEmail.Prepare;

    // Create the Insert for email
    sql := 'Insert into tblEmail (ID, emailAddress, LastUpdatedBy, DateLastUpdated) Values(:ID, :email, ''SYS'', Current_Timestamp)';
    dqInsertEmail.SQL.Add(sql);
    dqInsertEmail.Prepare;

    trueValue := LowerCase(trueValue); // standardize

    AssignFile(fInput, inputFile);
    Reset(fInput);
    lineCount := 0;
    errorCount := 0;

    // Speed up loop a little by skipping the header if necessary.
    if inputFileHasHeader and not Eof(fInput) then
    begin
      Readln(fInput, CSVLine);
      Inc(lineCount);
    end;

    tStart := GetTickCount;

    while not eof(fInput) do
    begin
      Readln(fInput, CSVLine);
      Inc(lineCount);

      VerboseWrite(Format('Line %d:', [lineCount]));

      if (lineCount mod 1000 = 0) then
        VerboseWrite('.');

      try
        sCSVValue := ParseCSV(csvLine, items);
        for iMap := Low(mappings) to High(mappings) do
        begin
          iMaxLen := mappings[iMap].MaxLength;
          iOffset := mappings[iMap].CSVOffset;
          fieldName := mappings[iMap].fieldName;

          sCSVValue := items[iOffset - 1];

          VerboseWrite(Format('Field "%s": Column %d = %s', [fieldName, iOffset, sCSVValue]));
          if (sCSVValue = '') and (not dsForTypes.FieldDefs.Find(fieldName).Required) then
            dqInsert.ParamByName(fieldName).Value := null

          else
          begin
            case dsForTypes.FieldByName(fieldName).DataType of
              ftUnknown, ftString :
              begin
                if (Length(sCSVValue) > iMaxLen) and (truncateStrings) then
                  begin
                    dqInsert.ParamByName(fieldName).AsString := LeftStr(sCSVValue, iMaxLen);
                    VerboseWrite(Format('Truncated String: %s ',[sCSVValue]));
                  end
                else
                  dqInsert.ParamByName(fieldName).AsString := sCSVValue;
              end;

              ftSmallint, ftInteger, ftWord, ftLargeint :
              begin
                dqInsert.ParamByName(fieldName).AsInteger := StrToInt(sCSVValue);
              end;
              ftBoolean : dqInsert.ParamByName(fieldName).Value := LowerCase(sCSVValue) = trueValue;
              ftFloat : dqInsert.ParamByName(fieldName).AsFloat := StrToFloat(sCSVValue);
              ftCurrency : dqInsert.ParamByName(fieldName).AsCurrency := StrToCurr(sCSVValue);
              ftDate : dqInsert.ParamByName(fieldName).AsDate := StrToDate(sCSVValue);
              ftTime : dqInsert.ParamByName(fieldName).AsDate := StrToTime(sCSVValue);
              ftDateTime : dqInsert.ParamByName(fieldName).AsDate := StrToDateTime(sCSVValue);
              else
                  if (dqInsert.ParamByName(fieldName).Size < Length(sCSVValue)) and (truncateStrings =true) then
                    begin
                      dqInsert.ParamByName(fieldName).AsString := LeftStr(sCSVValue, dqInsert.ParamByName(fieldName).Size );
                      WriteLn(Format('Truncated String: [%s] ',[sCSVValue]));
                    end
                  else
                    dqInsert.ParamByName(fieldName).AsString := sCSVValue;

            end;
          end;
        end;
      except
        on e : Exception do
        begin
          WritelnError(Format('Exception at line %d. %s', [lineCount, e.Message]));
          exit;
        end;

      end;

      try
        dqInsert.ExecSQL;
      except
        on e : Exception do
        begin
          Inc(ErrorCount);
          WritelnError(Format('Exception importing line %d. %s', [lineCount, e.Message]));
          if ErrorCount > 1000 then
            raise Exception.Create('Too many exceptions');
        end;

      end;

    end;

    Writeln;
    Writeln(Format('Done importing. %d seconds. %d lines processed. %d errors.', [(GetTickCount() - tStart) div 1000, lineCount, errorCount]));

  finally

    // Turn triggers on if we can.
    if disableTriggers then
    begin
      sql := Format('Enable Triggers on "%s"', [tableName]);
      ds.SQL.Add(sql);
      ds.ExecSQL;
      ds.SQL.Clear;
    end;


  end;

  FreeAndNil(ds);
  FreeAndNil(dqInsert);
  FreeAndNil(dqFindEmail);
  FreeAndNil(dqInsertEmail);
  FreeAndNil(db);
end;



end.

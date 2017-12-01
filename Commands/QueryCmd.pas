unit QueryCmd;

interface

procedure Query(sql : String;
              maxStringLength : Integer;
      				databaseName : String;
              userId, password : String;
              hostName : String;
              hostPort : Integer;
              dumpStrings : Boolean;
              format : String;  // table - fixed width, csv - comma separated value, json - JSON, mustache - requires file.
              includeHeader : Boolean;
              mustacheFile : String
              );

implementation
uses
  Math,
  Classes,
  SysUtils,
  StrUtils,

  db,
  edbcomps,

  SynMustache,

  DatasetJSON,
  SessionManager;


procedure Query(sql : String;
              maxStringLength : Integer;
      				databaseName : String;
              userId, password : String;
              hostName : String;
              hostPort : Integer;
              dumpStrings : Boolean;
              format : String;  // table - fixed width, csv - comma separated value, json - JSON, mustache - requires file.
              includeHeader : Boolean;
              mustacheFile : String
              );
var
  sessionMgr : TSessionManager;
	db : TEDBDatabase;
	dquery : TEDBQuery;
  dscript : TEDBScript;
  ds : TDataSet;
  iField: Integer;

  sName : String;
  iFieldLen : Integer;
  sValue : String;

  iString : Integer;
  sqlStrings : TStringList;

  function GetSQL(sql : String) : TStringList;
  var
  	f : TextFile;
    line,
    retVal : String;

  begin

    if sql[1] = '@' then // read from a file
    begin
    	AssignFile(f, strutils.RightStr(sql, length(sql) - 1));
      Reset(f);
      retVal := '';
      while not Eof(f) do
      begin
      	readln(f, line);
        retVal := retVal + #13#10 + line;
      end;
      CloseFile(f);

    end
    else
      retVal := sql;

    Result := TStringList.Create;
    Result.Delimiter := '!';
  	Result.StrictDelimiter := true;
    Result.DelimitedText := retVal;

  end;

  procedure WriteCSVField(s : String);
  begin
    Write('"' + ReplaceStr(s, '"', '""') + '"');
  end;

  procedure RenderMustache;
  var
    f : TextFile;
    s, line : String;
    mustache : TSynMustache;
  begin
    if mustacheFile[1] = '@' then // read from file
    begin
      AssignFile(f, strutils.RightStr(mustacheFile, length(mustacheFile) - 1));
      Reset(f);
      s := '';
      while not Eof(f) do
      begin
      	readln(f, line);
        s := s + #13#10 + line;
      end;
      CloseFile(f);
    end
    else
      s := mustacheFile;

    mustache := TSynMustache.Parse(s);
;
//        '{{#ds}}Hello {{name}}! You have just won {{value}} dollars!'#13#10'{{/ds}}');
    Writeln(ReplaceStr(mustache.RenderJSON(DatasetToJSONArray(ds, 'ds'), nil, mustache.HelpersGetStandardList()), '\n', #13#10));


  end;

begin
	sessionMgr := TSessionManager.Create(userId, password, hostName, hostPort);

  db := TEDBDatabase.Create(nil);
  db.OnStatusMessage := sessionMgr.Status;
  db.OnLogMessage := sessionMgr.Status;
	sqlStrings := GetSQL(sql);

  try
	  db.SessionName := sessionMgr.session.Name;
    db.Database := databaseName;
    db.LoginPrompt := true;
    db.DatabaseName := databaseName + DateTimeToStr(now);

    if dumpStrings then
			writeln('num strings:' + IntToStr(sqlStrings.Count));

    for iString := 0 to sqlStrings.Count - 1 do
    begin
      if Trim(sqlStrings[iString]) = '' then
        Continue;

	    if dumpStrings then
				writeln(' string ' + IntToStr(iString) + #13#10 + sqlStrings[iString]);

      if Pos('SCRIPT', Trim(UpperCase(sqlStrings[iString]))) = 1 then
      begin
        dscript := TEDBScript.Create(nil);
        dscript.SessionName := sessionMgr.session.SessionName;
        dscript.DatabaseName := db.Database;
        dscript.OnStatusMessage := sessionMgr.Status;
        dscript.OnLogMessage := sessionMgr.Status;
        dscript.SQL.Add(sqlStrings[iString]);

        dscript.ExecScript;
        ds := dscript;
      end

      else
      begin
        dquery := TEDBQuery.Create(nil);
        dquery.SessionName := sessionMgr.session.SessionName;
        dquery.DatabaseName := db.Database;
        dquery.OnStatusMessage := sessionMgr.Status;
        dquery.OnLogMessage := sessionMgr.Status;

        dquery.SQL.Add(sqlStrings[iString]);
        dquery.ExecSQL;

        ds := dquery;
      end;

      // Field Names
      if ds.Fields.Count > 0 then
      begin
        if includeHeader and (format <> 'json') and (format <> 'mustache') then
        begin
          for iField := 0 to ds.Fields.Count - 1 do
          begin
            sName := ds.Fields[iField].FieldName;

            if format = 'table' then
            begin
              case ds.Fields[iField].DataType of
                ftString :  begin
//                  iFieldLen := Max(ds.Fields[iField].Size, length(sName));
                  iFieldLen := Max(maxStringLength, iFieldLen);
                end;
                ftBoolean:  iFieldLen := Max(5, length(sName));
                ftDateTime: iFieldLen := Max(25, length(sName));
                ftMemo: iFieldLen := Max(maxStringLength, length(sName));
                else
                  iFieldLen := Max(10, length(sName));
              end;

              write(sName);
              write(StrUtils.DupeString(' ', iFieldLen - length(sName)));
              write(' ');
            end

            else
            begin
              WriteCSVField(sName);
              if iField < ds.Fields.Count - 1 then
                Write(',');
            end;
          end;
          writeln;

          // Underlines under field names
          if format = 'table' then
          begin
            for iField := 0 to ds.Fields.Count - 1 do
            begin
              sName := ds.Fields[iField].FieldName;
              case ds.Fields[iField].DataType of
                ftString :  begin
//                  iFieldLen := Max(ds.Fields[iField].Size, length(sName));
                  iFieldLen := Max(maxStringLength, iFieldLen);
                end;
                ftBoolean:  iFieldLen := Max(5, length(sName));
                ftDateTime: iFieldLen := Max(25, length(sName));
                ftMemo: iFieldLen := Max(maxStringLength, length(sName));
                else
                  iFieldLen := Max(10, length(sName));
              end;

              write(StrUtils.DupeString('=', iFieldLen));
              write(' ');
            end;
            writeln;
          end;
        end;

      end; // if fields.count > 0

      if format = 'json' then
        Writeln(DatasetToJSONArray(ds, 'ds'))

      else if format = 'mustache' then
        RenderMustache

      else
      begin
        while not ds.EOF do
        begin

          for iField := 0 to ds.Fields.Count - 1 do
          begin
            sName := ds.Fields[iField].FieldName;

            case ds.Fields[iField].DataType of
              ftString : begin
                sValue := ds.FieldByName(sName).AsString;

                // TODO: Remove
//                if lowercase(sName) = 'cc' then
//                  sValue := DecryptPassword(sValue);

  //              iFieldLen := Max(ds.Fields[iField].Size, length(sName));
                iFieldLen := Max(maxStringLength, iFieldLen);

                if length(sValue) > iFieldLen then
                  sValue := Copy(sValue, 1, iFieldLen);

              end;

              ftBoolean:  begin
                if ds.FieldByName(sName).AsBoolean then
                  sValue := 'True'
                else
                  sValue := 'False';

                iFieldLen := Max(5, length(sName));

              end;

              ftSmallint, ftInteger, ftWord: begin
                sValue := ds.FieldByName(sName).AsString;

                iFieldLen := Max(10, length(sName));
              end;

              ftFloat: begin
                sValue := ds.FieldByName(sName).AsString;
                iFieldLen := Max(10, length(sName));
              end;

              ftDateTime: begin
                sValue := ds.FieldByName(sName).AsString;
                iFieldLen := Max(25, length(sName));
              end;

              ftMemo: begin
                sValue := ds.FieldByName(sName).AsString;
                iFieldLen := Max(maxStringLength, length(sName));
              end

              else
              begin
                sValue := ds.FieldByName(sName).AsString;

                iFieldLen := Max(10, length(sName));
              end;
            end;

            if format = 'table' then
            begin
              write(sValue);
              write(StrUtils.DupeString(' ', iFieldLen - length(sValue)));
              write(' ');
            end

            else if format='csv' then
            begin
              WriteCSVField(sValue);
              if iField < ds.Fields.Count - 1 then
                Write(',');
            end;

          end;
          writeln;

          ds.Next;
        end;
      end;

		  FreeAndNil(ds);
    end; // iString

  finally
	  FreeAndNil(db);
    FreeAndNil(sqlStrings);
    FreeAndNil(sessionMgr);

  end;

end;


end.

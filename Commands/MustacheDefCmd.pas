unit MustacheDefCmd;

interface
procedure MustacheDef(
              tableName : string;
              mustacheFile : String;
              extraJSON : string;
      				databaseName : String;
              userId, password : String;
              hostName : String;
              hostPort : Integer);

implementation
uses
  SysUtils,
  StrUtils,
  db,

  edbcomps,
  SynMustache,

  SessionManager, JSONHelper;

procedure MustacheDef(
              tableName : string;
              mustacheFile : String;
              extraJSON : string;
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

  isFirstField : Boolean;

  json : String;

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
//        '{{#tableDef}}This is {{table}}! {{/tableDef}}');
    Writeln(ReplaceStr(mustache.RenderJSON(json, nil, mustache.HelpersGetStandardList()), '\n', #13#10));


  end;


(*
  "table" : "name",
  "fields" : [{"name":"xx",
             "isIdentity": false,
             "isGenerated": false,
             "type": "integer",
             "is<type>": "true", // so that mustache can do different things for different types
             "description": "abc",
             "length": 0,
             "precision": 0,
             "scale": 0
             }, ...]
*)
  function MakeFieldJSON(ds : TDataSet) : String;
  begin
    Result := '{' +
               JSONElement('name', ds.FieldByName('FieldName').AsString) + ',' +
               JSONElementBool('isIdentity', ds.FieldByName('Identity').AsBoolean) + ',' +
               JSONElementBool('isGenerated', ds.FieldByName('Generated').AsBoolean) + ',' +
               JSONElement('type', ds.FieldByName('Type').AsString) + ',' +
               JSONElementBool('is'+ds.FieldByName('Type').AsString, true) + ',' +
               JSONElement('description', ds.FieldByName('Description').AsString) + ',' +
               JSONElement('length', ds.FieldByName('Length').AsInteger) + ',' +
               JSONElement('precision', ds.FieldByName('Precision').AsInteger) + ',' +
               JSONElement('scale', ds.FieldByName('Scale').AsInteger) +
              '}';
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
             + 'c.Generated, c.Identity '
             + ' From Information.Tables t inner join Information.TableColumns c on t.Name = c.TableName ';
//  if tableName <> '*' then
    sSQL := sSQL + 'Where t.Name = ''' + tableName + ''' ';

  sSQL := sSQL + 'Order by t.Name, c.OrdinalPos';

  ds.SQL.Add(sSQL);
  ds.ExecSQL;

  json := '';

  isFirstField := true;
  while not ds.Eof do
  begin
    tableName := ds.FieldByName('TableName').AsString;

    if not isFirstField then
      json := json + ',';

    json := json + MakeFieldJSON(ds);

    isFirstField := false;
    ds.Next;
  end;
  FreeAndNil(ds);
  FreeAndNil(db);

  json := JSONArray('fields', json);

  json := '"tableDef": {' + JSONElement('table', tableName) + ',' + json + '}';
  if extraJSON <>  '' then
    json := json + ',' + extraJSON;

  json := '{' + json + '}';

  if mustacheFile = '' then
    Writeln(json)
  else
    RenderMustache;

end;

end.


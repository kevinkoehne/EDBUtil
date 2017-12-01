unit JSONHelper;

interface

function EscapeJSON(s : WideString) : String;
function JSONElement(name, value : WideString) : String; overload;
function JSONElement(name : String; value : Integer) : String; overload;
function JSONElementMoney(name : String; value : Double) : String;
function JSONElementDate(name : String; value : TDateTime) : String;
function JSONElementDateTime(name : String; value : TDateTime) : String;
function JSONElementBool(name : String; value : Boolean) : string;
function JSONElement(name : String; value : Boolean) : string; overload;
function JSONObject(name, sObjData : WideString) : string;
function JSONArray(name : String; sObjects : String) : string;

implementation
uses
  System.SysUtils;

function EscapeJSON(s : WideString) : String;
begin
  Result := StringReplace(StringReplace(s, '\', '\\', [rfReplaceAll]), '"', '\"', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '\\r', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '\\n', [rfReplaceAll]);
end;

function JSONElement(name, value : WideString) : String; overload;
begin
  Result := Format('"%s":"%s"', [EscapeJSON(name), EscapeJSON(value)]);
end;

function JSONElement(name : String; value : Integer) : String; overload;
var
  ws : WideString;
begin
  ws := Format('%d', [value]);
  Result := JSONElement(name, ws);
end;

function JSONElementMoney(name : String; value : Double) : String;
begin
  Result := JSONElement(name, FormatFloat('0.00', value));
end;

function JSONElementDate(name : String; value : TDateTime) : String;
begin
  Result := JSONElement(name, FormatDateTime('yyyy-mm-dd', value));
end;

function JSONElementDateTime(name : String; value : TDateTime) : String;
begin
  // TODO: This should really be zulu time...
  Result := JSONElement(name, FormatDateTime('yyyy-mm-dd hh:nn:ss AMPM', value));
end;

// Special version so boolean is not quoted.
function JSONElementBool(name : String; value : Boolean) : string;
begin
  if value then
    Result := Format('"%s":%s', [EscapeJSON(name), 'true'])
  else
    Result := Format('"%s":%s', [EscapeJSON(name), 'false'])
end;

function JSONElement(name : String; value : Boolean) : string; overload;
begin
  if value then
    Result := JSONElement(name, 'true')
  else
    Result := JSONElement(name, 'false');
end;

function JSONObject(name, sObjData : WideString) : string;
begin
  Result := Format('"%s":{%s}', [name, sObjData]);
end;

function JSONArray(name : String; sObjects : String) : string;
begin
  Result := Format('"%s":[%s]', [name, sObjects]);
end;
end.

unit CmdLineParameters;

interface
uses
  Classes;

  procedure Initialize;
  function ParamAsString(name : String; isRequired : Boolean = false; sDefault : String = '') : String;
  function ParamAsInteger(name : String; isRequired : Boolean = false; sDefault : String = '') : Integer;
  function ParamAsBoolean(name : String; isRequired : Boolean = false; sDefault : string = 'false') : boolean;
  function ParamExists(name : String) : boolean;

var
	params : TStringList = nil;

implementation
uses
  SysUtils,
  StrUtils;

// Gets params from switchs, both unary and binary
// All params start with '-' or '/'
// Unary parameters are simply flags (e.g. a boolean setting, where existence means true)
// Binary parameters start with a param, followed by a space, followed by the param value
//    for instance /path "c:\test"
procedure Initialize; //GetParams(params : TStringList);
var
  i : Integer;

  firstChar : String;
begin

  params := TStringList.Create;

  for i := 1 to ParamCount do
  begin
  	firstChar := LeftStr(ParamStr(i), 1);

  	if (firstChar = '/') or (firstChar = '-') then
    	params.Add(ParamStr(i))

    else
    begin
    	// This is assumed to be the value of a binary parameter
      if i > 0 then
      begin
      	params.Values[params[params.Count - 1]] := ParamStr(i);
      end;
    end;
  end;
end;

function ParamAsString(name : String; isRequired : Boolean = false; sDefault : String = '') : String;
var
  sVal : String;
begin
	sVal := params.Values[name];

  if sVal = '' then
  	sVal := sDefault;

  if (sVal = '') and (isRequired) then
    raise Exception.Create('Missing parameter ' + name)

  else
  begin
  	Result := sVal;

  end;
end;

function ParamAsInteger(name : String; isRequired : Boolean = false; sDefault : String = '') : Integer;
var
	sVal : String;

  retVal : Integer;
begin
	sVal := params.Values[name];

  if sVal = '' then
  	sVal := sDefault;

  if (sVal = '') and (isRequired) then
    raise Exception.Create('Missing parameter ' + name)

  else
  begin
  	if TryStrToInt(sVal, retVal) then
	  	Result := retVal

    else
    	raise Exception.Create('Invalid integer value for parameter ' + name);

  end;

end;

function ParamAsBoolean(name : String; isRequired : Boolean = false; sDefault : string = 'false') : boolean;
var
	sVal : String;

  retVal : boolean;
begin
	sVal := params.Values[name];

  if sVal = '' then
  	sVal := sDefault;

  if (sVal = '') and (isRequired) then
    raise Exception.Create('Missing parameter ' + name)

  else
  begin
  	if TryStrToBool(sVal, retVal) then
	  	Result := retVal

    else
    	raise Exception.Create('Invalid boolean value for parameter ' + name);

  end;

end;

function ParamExists(name : String) : boolean;
begin
 	Result := params.IndexOf(name) >= 0;
end;


end.

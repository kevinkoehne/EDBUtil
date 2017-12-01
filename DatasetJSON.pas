unit DatasetJSON;

interface
uses
  DB;

function DatasetToJSONArray(const ds : TDataset; arrayName : String = '') : string;

implementation
uses
  SysUtils,
  JSONHelper;

function DatasetRowToJSON(const ds:TDataset; makelowercase : Boolean = true):string;
var
  iField : integer;
  function fieldToJSON(thisField:TField):string;
  var
    name : String;
  begin
    if(makelowercase) then
      name := LowerCase(thisField.FieldName)
    else
      name := thisField.fieldName;

    case thisField.DataType of
      ftInteger,ftSmallint,ftLargeint:
        result := JSONElement(name, thisField.AsInteger);

      ftDate:
        result := JSONElementDate(name, thisField.AsDateTime);

      ftDateTime:
        result := JSONElementDateTime(name, thisField.AsDateTime);

      ftCurrency,
      ftFloat:
        result := JSONElement(name, FloatToStr(thisField.AsFloat));

      else
        result := JSONElement(name, thisField.AsString);

    end; // case
  end; // of fieldToJSON

begin
  result := '';

  for iField := 0 to ds.fieldcount - 1 do
  begin
    if iField > 0 then
      result := result + ',';

    result := result + fieldToJSON(ds.Fields[iField]);
  end;

  result := '{'+Result+'}';
end;

function DatasetToJSONArray(const ds : TDataset; arrayName : String = '') : string;
begin
  result := '';

  if (not ds.eof) and (ds <> nil) then
  begin
    ds.first;

    while not ds.eof do
    begin
      if Result <> '' then
        result := result + ',';
      result := result + DatasetRowToJSON(ds);
      ds.next;
    end;
  end;

  if arrayName = '' then
    result := '['+result+']'
  else
    Result := '{' + JSONArray(arrayName, Result) + '}';
end; // of DSToJSON

end.

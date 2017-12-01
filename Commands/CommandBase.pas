unit CommandBase;

interface
uses
  Classes;

type
  TCommandBase = class
  protected
    op : string;
  public
    constructor Create(op : String);
    destructor Destroy; override;

    procedure Execute(databaseName : String;
              userId, password : String;
              hostName : String;
              hostPort : Integer;
              params : TStringList); virtual; abstract;
  end;

implementation

{ TCommandBase }

constructor TCommandBase.Create(op: String);
begin

end;

destructor TCommandBase.Destroy;
begin

  inherited;
end;

end.

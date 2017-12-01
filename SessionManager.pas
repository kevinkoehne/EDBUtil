unit SessionManager;

interface
uses
  edbcomps;

type
	TSessionManager = class
  public
	  session : TEDBSession;
    constructor Create(userId, password, hostName : String; hostPort : Integer);
    destructor Destroy; override;

	 	procedure Status(Sender: TObject; const StatusMessage: String);
    procedure OnRemoteTimeout(Sender: TObject; var StayConnected : boolean);
  end;


implementation
uses
  SysUtils,
  StrUtils,

  ConsoleHelper;

{ TSessionManager }

constructor TSessionManager.Create(userId, password, hostName : String; hostPort : Integer);
begin
  session := TEDBSession.Create(nil);
  session.OnStatusMessage := Status;
  session.OnLogMessage := Status;
  session.AutoSessionName := true;
  session.SessionType := stRemote;
  session.LoginUser := userId;
  session.LoginPassword := password;
  session.CharacterSet := csAnsi;
  if AnsiLeftStr(hostName, 2) = '\\' then
		session.RemoteHost := AnsiRightStr(hostName, length(hostName) - 2)  // '\\hostname'
  else
	  session.RemoteAddress := hostName; //'127.0.0.1';
  session.RemotePort := hostPort; //12010;
  session.OnRemoteTimeout := OnRemoteTimeout;

end;

destructor TSessionManager.Destroy;
begin
	FreeAndNil(session);
end;

procedure TSessionManager.OnRemoteTimeout(Sender: TObject;
  var StayConnected: boolean);
var
  c : Char;
begin
  Write('This process is taking a long time... Continue (y/n)');
  repeat
    Read(c);
    if c in ['y', 'Y'] then
      StayConnected := True
    else if c in ['n', 'N'] then
      StayConnected := True
    else
      writeln('Try y or n');
  until c in ['y', 'Y', 'n', 'N'];
end;

procedure TSessionManager.Status(Sender: TObject; const StatusMessage: String);
begin
  VerboseWrite(StatusMessage);
end;

end.

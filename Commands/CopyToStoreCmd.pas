unit CopyToStoreCmd;

interface

procedure CopyToStore(fqFileName, StoreName : string;
              userId, password : String;
              hostName : String;
              hostPort : Integer);

implementation
uses
  Classes,
  SysUtils,

  SessionManager;

procedure CopyToStore(fqFileName, StoreName : string;
              userId, password : String;
              hostName : String;
              hostPort : Integer);
var
  sessionMgr : TSessionManager;
  stream : TFileStream;
begin
	sessionMgr := TSessionManager.Create(userId, password, hostName, hostPort);
  stream := TFileStream.Create(fqFileName, fmOpenRead);
  try
    sessionMgr.session.Open;
    sessionMgr.session.SaveStreamToStoreFile(storeName, ExtractFileName(fqfileName), stream);
    sessionMgr.session.Close;
  finally
    sessionMgr.Free;
    stream.Free;
  end;

end;
end.

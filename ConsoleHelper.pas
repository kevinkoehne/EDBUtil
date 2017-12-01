unit ConsoleHelper;

interface

procedure WritelnAttrib(s : String; attributes : word; asError : Boolean = false);
procedure WritelnInfo(s : String); // writes BOLD, YELLOW
procedure WritelnError(s : string); // red, to stderr
procedure WritelnStatus(s : String); // bold white

procedure SetVerbosity(verbosity : Boolean);

procedure VerboseWrite(msg : String);

implementation
uses
  Windows;

var
  isVerbose : Boolean;
procedure SetVerbosity(verbosity : Boolean);
begin
  isVerbose := verbosity;
end;

procedure VerboseWrite(msg : String);
begin
  if isVerbose then
    Writeln(msg);
end;

procedure WritelnInfo(s : String);
begin
  WritelnAttrib(s, FOREGROUND_RED or FOREGROUND_GREEN or FOREGROUND_INTENSITY);
end;

procedure WritelnError(s : string);
begin
  WritelnAttrib(s, FOREGROUND_RED or FOREGROUND_INTENSITY, true);
end;

procedure WritelnStatus(s : String);
begin
  WritelnAttrib(s, FOREGROUND_RED or FOREGROUND_GREEN or FOREGROUND_BLUE or FOREGROUND_INTENSITY);
end;

procedure WritelnAttrib(s : String; attributes : word; asError : Boolean = false);
var
  sbi : TConsoleScreenBufferInfo;

begin
	// Get the current attributes
  GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), sbi);

  // Set the new attributes
  SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), attributes);

  if asError then
    writeln(ErrOutput, s)
  else
    writeln(s);

  // restore attributes
  SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), sbi.wAttributes);
end;


end.

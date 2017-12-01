program EDBUtil;

{$APPTYPE CONSOLE}

uses
  DB,
  Math,
  Classes,
  AnsiStrings,
  SysUtils,
  StrUtils,
  Variants,
  edbcomps,
  edbtype,
  IniFiles,
  DatasetJSON in 'DatasetJSON.pas',
  ConsoleHelper in 'ConsoleHelper.pas',
  SessionManager in 'SessionManager.pas',
  SetDBPath in 'Commands\SetDBPath.pas',
  CmdLineParameters in 'CmdLineParameters.pas',
  QueryCmd in 'Commands\QueryCmd.pas',
  CommandBase in 'Commands\CommandBase.pas',
  VerifyRepairCmd in 'Commands\VerifyRepairCmd.pas',
  RestoreCmd in 'Commands\RestoreCmd.pas',
  ExportToMSSQLCmd in 'Commands\ExportToMSSQLCmd.pas',
  ImportCSVCmd in 'Commands\ImportCSVCmd.pas',
  ReleaseSessionsCmd in 'Commands\ReleaseSessionsCmd.pas',
  CopyToStoreCmd in 'Commands\CopyToStoreCmd.pas',
  MustacheDefCmd in 'Commands\MustacheDefCmd.pas',
  JSONHelper in 'JSONHelper.pas';

var
  isVerbose : Boolean;

procedure ShowHelp;
begin
  writeln('Elevate Database Utilities  Copyright(c) 2011 Bay Lakes Information Systems LLC');
  writeln('A utility for a variety of functions for Elevate DB');
  writeln('');
  writeln('Usage: EDBUtil <command> <parameters>');
  writeln('Commands:');
  writeln('  /setDBPath - sets the path for the database.');
  writeln('  Params:');
  writeln('      /configPath - path of the configuration for the database engine');
  writeln('      /newPath    - the new path for the database');
  writeln;
  writeln('  /query - executes a query against the database.');
  writeln('  Params:');
  writeln('      /sql       - sql to execute (use @ to specify a file containing the sql)');
  writeln('      /maxstring - maximum string length (default 50)');
  writeln('      /dump      - show the SQL statements (default false)');
  Writeln('      /format    - the format of the output. Possible options are Table, CSV, JSON, mustache. (default table)');
  writeln('      /NoHeader  - header not included in output.');
  writeln('      /Mustache  - Mustache template (use @ to specify a file containing a mustache template). NOTE: Use {{#ds}}{{/ds}} for section');
  writeln;
  writeln('  /mustacheDef - creates a JSON form of a table definition, and can map it to a mustache file.');
  writeln('  Params:');
  writeln('      /table     - name of table for which to generate JSON definition');
  writeln('      /mustach - Mustache template (use @ to specify a file containing a mustache template). NOTE: Use {{#tableDef}}{{#fields}}{{/fields}}{{/tableDef}} for section');
  writeln;
  writeln('  /verify - runs VERIFY on table.');
  writeln('  Params:');
  writeln('      /table     - name of table to verify (default *, means verify all)');
  Writeln('      /startat   - when repairing all, you can start at a specific table. Tables are in alpha order. (optional)');
  writeln;
  writeln('  /repair - runs REPAIR on table.');
  writeln('  Params:');
  writeln('      /table     - name of table to repair (default *, means repair all)');
  Writeln('      /startat   - when repairing all, you can start at a specific table. Tables are in alpha order. (optional)');
  writeln;
  writeln('  /restore - restores a backup to the database specified by /db parameter.');
  writeln('  Params:');
  writeln('      /store - name of the store which contains the backup (required)');
  writeln('      /name  - name of the backup file to restore. Use * to restore the file with the latest timestamp (required)');
  writeln('      /quiet - do not verify with user the name of the latest backup (e.g. when /name * is used)');
  writeln;
  writeln('  /Import - imports a CSV file into a table');
  writeln('  Params:');
  writeln('	    /table - table to which to import the data');
  writeln('	    /input - CSV file from which to get the data');
  writeln('	    /hasHeader - indicates that the CSV file''s first line is a header');
  writeln('	    /op - required. Specify APPEND to add the records to existing data. Specify OVERWRITE to delete existing data.');
  writeln('	    /map - list of field names and column position in CSV in the form "fieldnameA=x;fieldnameB=y"');
  writeln('	    	   Where fieldNameA and fieldNameB are names in the table');
  writeln('	    			     x and y are the column positions to import into the table.');
  writeln('	    	   if the /map parameter starts with @, then the mappings are read from a file');
  writeln('	    /disableTriggers - turn off triggers on table. This is useful if there are triggers that update');
  writeln('					           data (like LastUpdatedDate).');
  Writeln('     /trueValue - the value in a column that represents TRUE. Everything else is false. Default true');
  Writeln('     /emailNumField - field that is mapped from an email address to an entry into tblEmail');
  WriteLn('     /truncStrings - Truncate strings that are too long');
  Writeln;
  Writeln('  /MSSQL - exports create table and data');
  writeln('  Params:');
  writeln('	    /table - table for which to create MSSQL stuff');
  writeln;
  Writeln('  /ReleaseSessions - releases all of the sessions on the selected database.');
  Writeln;
  Writeln('  /CopyToStore - copys a local file to an Elevate store. Useful when copying workstation files to the server.');
  Writeln('  Params:');
  Writeln('     /file - name of the file to copy');
  Writeln('     /store - name of the Elevate store to which to copy');
  writeln;
  Writeln('  /CreateDB - creates a new database');
  Writeln('  Params:');
  Writeln('      /name - name of the database');
  Writeln('      /path - location of database');
  writeln;
  writeln('All commands require the following parameters:');
  writeln('  /db        - database name');
  writeln('  /userid    - database user id');
  writeln('  /pwd       - database password');
  writeln('  /hostName  - name of the server');
  writeln('  /hostPort  - the port number to communicate with the server (default 12010)');
  writeln;
  writeln('Special Switches:');
  writeln('   /verbose displays more information');
  writeln('   /nostop  won''t wait for enter key after exception');
end;


procedure GetStandardParams(var hostName, userId, pwd, db : String; var hostPort : Integer);
begin
  hostName := ParamAsString('/hostName', true);
  userId := ParamAsString('/userid', true);
  pwd := ParamAsString('/pwd', true);
  db := ParamAsString('/db', true);
  hostPort := ParamAsInteger('/hostPort', false, '12010');
end;

var
	hostName, userId, pwd, db : String;
  hostPort : Integer;

  storeName : String;

begin

  CmdLineParameters.Initialize;

  ExitCode := 0;

  try
    // the first parameter indicates the operation:
    if params.Count = 0 then
    begin
    	ShowHelp;
      ExitCode := 1;
    end

    else if lowercase(params[0]) = '/help' then
    	ShowHelp

    else // real command
    begin
      isVerbose := ParamExists('/verbose');
      ConsoleHelper.SetVerbosity(isVerbose);

    	GetStandardParams(hostName, userid, pwd, db, hostPort);

      if lowercase(params[0]) = '/setdbpath' then
      begin
        SetDatabasePath(ParamAsString('/configPath', true),
                        ParamAsString('/newPath', true),
                        db,
                        userid,
                        pwd,
                        hostName,
                        hostPort);
      end

      else if lowercase(params[0]) = '/query' then
      begin
        Query(ParamAsString('/sql', true),
              ParamAsInteger('/maxString', false, '50'),
              db,
              userId,
              pwd,
              hostName,
              hostPort,
              ParamExists('/dump'),
              LowerCase(ParamAsString('/format', False, 'Table')),
              Not ParamExists('/noheader'),
              ParamAsString('/mustache'));
      end
    
      else if lowercase(params[0]) = '/verify' then
      begin
        VerifyRepair('VERIFY',
          ParamAsString('/table', false, '*'),
          ParamAsString('/startat', False, ''),
          db,
          userid,
          pwd,
          hostName,
          hostPort);
      end


      else if lowercase(params[0]) = '/repair' then
      begin
        VerifyRepair('REPAIR',
          ParamAsString('/table', false, '*'),
          ParamAsString('/startat', False, ''),
          db,
          userid,
          pwd,
          hostName,
          hostPort)
      end

      else if lowercase(params[0]) = '/restore' then
      begin
        storeName := ParamAsString('/store', true);

        Restore(
              storeName,
              ParamAsString('/name', true),
              Not ParamExists('/quiet'),
              db,
              userId,
              pwd,
              hostName,
              hostPort);
      end

      else if lowercase(params[0]) = '/mssql' then
      begin
        ExportToMSSQL(
                  ParamAsString('/table', false, '*'),
                  db,
                  userId,
                  pwd,
                  hostName,
                  hostPort);
      end

      else if lowercase(params[0]) = '/import' then
      begin
        ImportCSV(ParamAsString('/table', true),
                  ParamAsString('/input', true),
                  ParamExists('/hasHeader'),
                  ParamAsString('/map', true),
                  ParamAsString('/op', true),
                  ParamExists('/disableTriggers'),
                  ParamAsString('/date', False, ''),
                  ParamAsString('/truevalue', False, 'true'),
                  ParamAsString('/emailnumField', False, ''),
                  ParamExists('/truncStrings'),
                  db,
                  userId,
                  pwd,
                  hostName,
                  hostPort);
      end

      else if LowerCase(params[0]) = '/releasesessions' then
      begin
        ReleaseSessions(db,
                  userId,
                  pwd,
                  hostName,
                  hostPort);
      end

      else if LowerCase(params[0]) = '/copytostore' then
        CopyToStore(ParamAsString('/file', true),
                  ParamAsString('/store', true),
                  userId,
                  pwd,
                  hostName,
                  hostPort)

      else if LowerCase(params[0]) = '/delstorefile' then
        Query(Format('Delete File "%s" FROM store "%s"', [ParamAsString('/file', true), ParamAsString('/store', true)]), 255, 'Configuration', userId, pwd, hostName, hostPort, false, '', false, '')

      else if LowerCase(params[0]) = '/mustachedef' then
      begin
        MustacheDef(ParamAsString('/table', true),
                    ParamAsString('/mustache', false),
                    ParamAsString('/extraJSON', false),
                    db,
                    userId,
                    pwd,
                    hostName,
                    hostPort);
      end

      else if LowerCase(params[0]) = '/test' then
//        Test(db,
//                  userId,
//                  pwd,
//                  hostName,
//                  hostPort)

      else
      begin
        ShowHelp;
        ExitCode := 1;
      end;
    end;

  except
    on E:Exception do
    begin
  		ExitCode := 100;

      WritelnError(E.Classname + ': ' + E.Message);
      if not ParamExists('/nostop') then
        readln;
    end;
  end;
end.

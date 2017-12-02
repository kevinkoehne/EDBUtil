# EDBUtil
A command-line utility for working with an Elevate Software database.

## Dependencies
* ElevateSoft Elevate Database libraries
* Delphi XE+

## Usage
EDBUtil \<command\> \<parameters\>

_Commands_:

    /setDBPath - sets the path for the database.  
    Params:  
        /configPath - path of the configuration for the database engine  
        /newPath    - the new path for the database

    /query - executes a query against the database.  
    Params:  
      /sql       - sql to execute (use @ to specify a file containing the sql)  
      /maxstring - maximum string length (default 50)  
      /dump      - show the SQL statements (default false)  
      /format    - the format of the output. Possible options are Table, CSV, JSON, mustache. (default table)  
      /NoHeader  - header not included in output.  
      /Mustache  - Mustache template (use @ to specify a file containing a mustache template NOTE: Use {{#ds}}{{/ds}} for section

    /mustacheDef - creates a JSON form of a table definition, and can map it to a mustache file.  
    Params:
      /table     - name of table for which to generate JSON definition
      /mustach - Mustache template (use @ to specify a file containing a mustache template). NOTE: Use {{#tableDef}}{{#fields}}{{/fields}}{{/tableDef}} for section

    /verify - runs VERIFY on table.
    Params:
      /table     - name of table to verify (default *, means verify all)
      /startat   - when repairing all, you can start at a specific table. Tables are in alpha order. (optional)

    /repair - runs REPAIR on table.
    Params:
      /table     - name of table to repair (default *, means repair all)
      /startat   - when repairing all, you can start at a specific table. Tables are in alpha order. (optional)

    /restore - restores a backup to the database specified by /db parameter.
    Params:
      /store - name of the store which contains the backup (required)
      /name  - name of the backup file to restore. Use * to restore the file with the latest timestamp (required)
      /quiet - do not verify with user the name of the latest backup (e.g. when /name * is used)

    /Import - imports a CSV file into a table
    Params:
      /table - table to which to import the data
      /input - CSV file from which to get the data
      /hasHeader - indicates that the CSV file's first line is a header
      /op - required. Specify APPEND to add the records to existing data. Specify OVERWRITE to delete existing data.
      /map - list of field names and column position in CSV in the form "fieldnameA=x;fieldnameB=y"
           Where fieldNameA and fieldNameB are names in the table
           x and y are the column positions to import into the table.
           if the /map parameter starts with @, then the mappings are read from a file
      /disableTriggers - turn off triggers on table. This is useful if there are triggers that update data (like LastUpdatedDate).
      /trueValue - the value in a column that represents TRUE. Everything else is false. Default true
      /truncStrings - Truncate strings that are too long

    /MSSQL - exports create table and data
    Params:
	  /table - table for which to create MSSQL stuff

    /ReleaseSessions - releases all of the sessions on the selected database.

    /CopyToStore - copys a local file to an Elevate store. Useful when copying workstation files to the server.
    Params:
     /file - name of the file to copy
     /store - name of the Elevate store to which to copy

    /CreateDB - creates a new database
    Params:
      /name - name of the database
      /path - location of database

All commands require the following parameters:

    /db        - database name
    /userid    - database user id
    /pwd       - database password
    /hostName  - name of the server
    /hostPort  - the port number to communicate with the server (default 12010)

Special Switches:

    /verbose displays more information
    /nostop  won't wait for enter key after exception


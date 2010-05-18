unit CommonTypesUnit;

interface

uses
  Windows;

type
  TResult = (
    RESULT_AC,
    RESULT_WA,
    RESULT_PE,
    RESULT_IE,
    RESULT_TL,
    RESULT_RE,
    RESULT_CE,
    RESULT_ML);

  TProblemParams = class
  public
    fId: Integer;
    fTestCount: Integer;
    fTimeLimit: Integer;
    fMemoryLimit: Integer;
  end;

const

  RESULT_STR: array [RESULT_AC..RESULT_ML] of string = ('Accepted', 'Wrong asnswer', 'Presentation error', 'Internal error', 'Time limit', 'Run-time error', 'Compilation error', 'Memory limit');
  JAVA_FILE_MUST_BE_RENAMED = 'is public, should be declared in a file named ';
  OPTIONS_FILE_NAME = 'config.ini';
  UPDATE_QUERY_STRING = 'UPDATE results SET result=%d, description=''%s'', last_test=%d, run_time=%d, memory_usage=%d WHERE id=%d';
  SELECT_QUERY_STRING = 'SELECT problem, language, file, ip, id FROM results WHERE result=-1 AND id NOT IN (%s) ORDER BY id ASC';
  PEEK_QUERY_STRING = 'SELECT COUNT(*) FROM results WHERE result = -1';

function Ansi2Oem(s: AnsiString): AnsiString;

implementation

function Ansi2Oem(s: AnsiString): AnsiString;
var
  Buffer: array of AnsiChar;
begin
  SetLength(Buffer, Length(s) + 1);
  AnsiToOem(PAnsiChar(s), @Buffer[0]);
  Result := PAnsiChar(@Buffer[0]);
end;

end.

unit ProblemParamsUnit;

interface

uses
  SysUtils, SqlExpr, ZDbcIntfs,
  OptionsUnit, CommonTypesUnit, DataBaseUnit;

type
  TProblemParamsCache = class(TObject)
  private
    fCache: array of TProblemParams;
    function GetProblemParams(Problem: Integer): TProblemParams;
  public
    constructor Create;
    destructor Destroy; override;
    property ProblemParams[Index: Integer]: TProblemParams read GetProblemParams; default;
  end;

var
  ProblemParamsCache: TProblemParamsCache;

implementation

constructor TProblemParamsCache.Create;
begin
  SetLength(fCache, 5000);
end;

destructor TProblemParamsCache.Destroy;
var
  i: Integer;
begin
  for i := 0 to Length(fCache) - 1 do
    if fCache[i] <> nil then
      fCache[i].Free;
  SetLength(fCache, 0);

  inherited;
end;

function TProblemParamsCache.GetProblemParams(Problem: Integer): TProblemParams;
var
  QueryResult: IZResultSet;
begin
  Result := nil;

  if Problem < 1001 then
    raise Exception.CreateFmt('Invalid problem id: %d is requested', [Problem]);

  if fCache[Problem - 1001] <> nil then
    Result := fCache[Problem - 1001] as TProblemParams
  else
  begin
    QueryResult := DataBase.ExecuteQuery(Format('SELECT runtime_limit, test_amount, memory_limit FROM problems where id = ''%d''', [Problem]));
    try
      if QueryResult.First then
      begin
        Result := TProblemParams.Create;
        Result.fTimeLimit := QueryResult.GetInt(1);
        Result.fTestCount := QueryResult.GetInt(2);
        Result.fMemoryLimit := QueryResult.GetInt(3);
        Result.fId := Problem;
        fCache[Problem - 1001] := Result;
      end
      else
        raise Exception.CreateFmt('Problem with id = %d is not found in database', [Problem]);
    finally
      QueryResult.Close;
    end;
  end;
end;

end.

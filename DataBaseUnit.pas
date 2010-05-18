unit DataBaseUnit;

interface

uses
  Windows, SysUtils, ZDbcIntfs, ZDbcMySql,
  OptionsUnit;

type

  TDataBase = class(TObject)
  private
    fConnection: IZConnection;
    fStatement: IZStatement;
    fThreadSafeConnection: IZConnection;
    fThreadSafeStatement: IZStatement;
    fCriticSec: _RTL_CRITICAL_SECTION;
  public
    constructor Create;
    destructor Destroy; override;
    function ExecuteQuery(Query: string): IZResultSet;
    function ThreadSafeExecuteUpdate(Query: string): Integer;
  end;

var
  DataBase: TDataBase;

implementation

{ TDataBase }

constructor TDataBase.Create;
begin
  fConnection := DriverManager.GetConnection(Format('zdbc:mysql://%s/%s?UID=%s;PWD=%s', [
    Options['Main', 'DataBaseHost'],
    Options['Main', 'DataBaseName'],
    Options['Main', 'DataBaseUserName'],
    Options['Main', 'DataBasePassword']
  ]));

  fThreadSafeConnection := DriverManager.GetConnection(Format('zdbc:mysql://%s/%s?UID=%s;PWD=%s', [
    Options['Main', 'DataBaseHost'],
    Options['Main', 'DataBaseName'],
    Options['Main', 'DataBaseUserName'],
    Options['Main', 'DataBasePassword']
  ]));

  fStatement := fConnection.CreateStatement();
  fThreadSafeStatement := fThreadSafeConnection.CreateStatement;
  fThreadSafeStatement.Execute('SET NAMES CP1251');

  InitializeCriticalSection(fCriticSec);
//  fStatement.SetResultSetConcurrency(rcUpdatable);
end;

destructor TDataBase.Destroy;
begin
  fStatement.Close;
  fConnection.Close;
  fThreadSafeStatement.Close;
  fThreadSafeConnection.Close;
  DeleteCriticalSection(fCriticSec);
  inherited
end;

function TDataBase.ExecuteQuery(Query: string): IZResultSet;
begin
  Result := fStatement.ExecuteQuery(Query);
end;

function TDataBase.ThreadSafeExecuteUpdate(Query: string): Integer;
begin
  EnterCriticalSection(fCriticSec);
  Result := fThreadSafeStatement.ExecuteUpdate(Query);
  LeaveCriticalSection(fCriticSec);
end;

end.

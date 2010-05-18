unit MainUnit;

interface

uses
  Windows, Sysutils, Classes, ZDbcIntfs, Types,
  OptionsUnit, CommonTypesUnit, DataBaseUnit, SubmitUnit, ThreadsListUnit, ActiveSubmitsIdListUnit;

type
  TMainClass = class(TObject)
  private

  protected

  public
    constructor Create;
    destructor Destroy; override;
    procedure Execute;
  end;

var
  Main: TMainClass;

implementation

{ TMainClass }

constructor TMainClass.Create;
begin

end;

destructor TMainClass.Destroy;
begin

  inherited;
end;

procedure TMainClass.Execute;
var
  Problem: Integer;
  Language: Integer;
  SourceFile: TBytes;
  RemoteAddr: string;
  Id: Integer;
  Number: Integer;
  Query: string;

  Submit: TSubmit;
  QueryResult: IZResultSet;

  x: Cardinal;
begin
  while True do
  begin
    SetConsoleTitle(PChar('Waiting for new submits...'));
    Sleep(Options.CheckInterval);
    SetConsoleTitle(PChar('Requesting...'));
    Query := Format(SELECT_QUERY_STRING, [ActiveSubmitsIdList.MakeString]);
    QueryResult := DataBase.ExecuteQuery(Query);
    try
      while QueryResult.Next do
      begin
        Problem := QueryResult.GetInt(1);
        Language := QueryResult.GetInt(2);
        SourceFile := TBytes(QueryResult.GetBytes(3));
        RemoteAddr := QueryResult.GetString(4);
        Id := QueryResult.GetInt(5);

        SetConsoleTitle(PChar('New submit: ' + IntToStr(Id) + '. Starting new thread...'));
        Number := ThreadsList.Reserve;
        Submit := TSubmit.Create(Number, Id, Problem, Language, SourceFile, RemoteAddr);
        Submit.FreeOnTerminate := True;
        Submit.Resume;
        SetConsoleTitle(PChar('Thread ' + IntToStr(Number) + ' started...'));
        Sleep(10);
      end;
    finally
      QueryResult.Close;
    end;
  end;
end;

end.

unit SubmitUnit;


interface

uses
  Windows, SysUtils, StrUtils, Classes, SqlExpr,
  OptionsUnit, CommonTypesUnit, ProblemParamsUnit, CompilerUnit, SandBoxUnit, CheckerUnit, DataBaseUnit, ActiveSubmitsIdListUnit, ThreadsListUnit;

type
  TSubmit = class(TThread)
  private
    fNumber: Integer;
    fId: Integer;
    fRemoteAddr: string;
    fProblemParams: TProblemParams;
    fCompiler: TCompiler;
    fSandBox: TSandBox;
    fChecker: TChecker;
    fSourceFile: TBytes;
    fResult: TResult;
    fMessage: string;
    fLastTest: Integer;
    fWorkDirectory: string;
    procedure Check;
  public
    constructor Create(ThreadNumber, Id, Problem, Language: Integer; SourceFile: TBytes; const RemoteAddr: string); reintroduce;
    destructor Destroy; override;
  protected
    procedure Execute; override;
  end;

implementation

constructor TSubmit.Create(ThreadNumber, Id, Problem, Language: Integer; SourceFile: TBytes; const RemoteAddr: string);
begin
  inherited Create(True);

  try
    fNumber := ThreadNumber;
    fId := Id;
    ActiveSubmitsIdList.Add(fId);

    fRemoteAddr := RemoteAddr;
    fSourceFile := SourceFile;

    fProblemParams := ProblemParamsCache[Problem];

    fCompiler := CompilerCollection[Language];
    fWorkDirectory := Options.WorkDirectory + 'Thread' + IntToStr(fNumber) + '\';
    if not DirectoryExists(fWorkDirectory) then
      ForceDirectories(fWorkDirectory);
    fCompiler.WorkDirectory := fWorkDirectory;

    fSandBox := TSandBox.Create;
    fSandBox.TimeLimit := fProblemParams.fTimeLimit;
    fSandBox.MemoryLimit:= fProblemParams.fMemoryLimit;
    fSandBox.WorkDirectory := fWorkDirectory;

    fChecker := TChecker.Create;
    fChecker.CheckerFileName := Options.ProblemsRootDirectory + IntToStr(fProblemParams.fId) + '\check.exe';
  except
    on E: Exception do
    begin
      fResult := RESULT_IE;
      fMessage := E.Message;
    end;
  end;
end;

destructor TSubmit.Destroy;
begin
  ThreadsList.Release(fNumber);
  fCompiler.Free;
  fSandBox.Free;
  fChecker.Free;
  SetLength(fSourceFile, 0);

  inherited;
end;


procedure TSubmit.Execute;
var
  Query: String;
begin
  if fResult = RESULT_AC then
  begin
    fResult := fCompiler.Compile(fSourceFile);
    if fResult = RESULT_AC then
    begin
      fSandBox.ExecutableFileName := fCompiler.ExecutableFileName;
      fSandBox.CommandLine := fCompiler.ExecutableCommandLine;
      Self.Check;
    end
    else
      fMessage := fCompiler.Message;
  end;

  if fResult = RESULT_IE then
    Query := Format(UPDATE_QUERY_STRING, [Ord(fResult), ReplaceText(ReplaceText(fMessage, '\', '\\'), '''', '\'''), 0, 0, 0, fId])
  else
    Query := Format(UPDATE_QUERY_STRING, [Ord(fResult), ReplaceText(ReplaceText(fMessage, '\', '\\'), '''', '\'''), fLastTest, fSandBox.RunTime, fSandBox.MemoryUsage, fId]);
  if DataBase.ThreadSafeExecuteUpdate(Query) <> 1 then
    raise Exception.Create('No rows affected after updating the sumbit');

  (*
    SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), FOREGROUND_GREEN);
    Write('Thread: ', fNumber, ' Id: ', fId, ', Remote Address: ');
    SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), FOREGROUND_BLUE);
    Writeln(fRemoteAddr);
    SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), FOREGROUND_GREEN);
    Writeln('  Problem: ', fProblemParams.fId, ', Language: ', fCompiler.LanguageName, ', Code size: ', (Length(fSourceFile) / 1024):0:2, ' kbytes');
    Write('  Result: ');
    SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), FOREGROUND_RED);
    Write(RESULT_STR[fResult]);
    SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), FOREGROUND_GREEN);
    Writeln(', Description: ', Ansi2Oem(fMessage));
    Writeln('  Run time: ', (fSandBox.RunTime / 1000):0:3, ' seconds', ' Memory usage: ', (fSandBox.MemoryUsage / 1024 / 1024):0:2, ' mbytes', ' Last test: ', fLastTest);
    Writeln;
  *)

  if fResult = RESULT_IE then
    MessageBeep(MB_ICONHAND);

  ActiveSubmitsIdList.Remove(fId);
end;

procedure TSubmit.Check;
var
  InputFileName: string;
  AnswerFileName: string;

  SecureAttr: TSecurityAttributes;
  hInputFileHandle, hAnswerFileHandle: THandle;

  hOutputPipeHandleRead, //for checker's STD_INPUT_HANDLE
  hOutputPipeHandleWrite: THandle; //for solution's STD_OUTPUT_HANDLE
begin
  fLastTest := 0;

  SecureAttr.nLength := SizeOf(SecureAttr);
  SecureAttr.lpSecurityDescriptor := nil;
  SecureAttr.bInheritHandle := True;

  try
    while (fLastTest < fProblemParams.fTestCount) and (fResult = RESULT_AC) do
    begin
      inc(fLastTest);

      InputFileName := Options.ProblemsRootDirectory + IntToStr(fProblemParams.fId) + Format('\input\input%d.txt', [fLastTest]);
      AnswerFileName := Options.ProblemsRootDirectory + IntToStr(fProblemParams.fId) + Format('\answer\answer%d.txt', [fLastTest]);

      hInputFileHandle := CreateFile(PChar(InputFileName), GENERIC_READ, FILE_SHARE_READ, @SecureAttr, OPEN_EXISTING, 0, 0);
      if hInputFileHandle = INVALID_HANDLE_VALUE then
        raise Exception.CreateFmt('Unable to open input file "%s" for reading: %s', [InputFileName, SysErrorMessage(GetLastError)]);

      try
        if not CreatePipe(hOutputPipeHandleRead, hOutputPipeHandleWrite, @SecureAttr, 1 * 1024 * 1024 * 100) then
          raise Exception.Create('Unable to create pipe for solution''s output');

        if FileExists(AnswerFileName) then
        begin
          hAnswerFileHandle := CreateFile(PChar(AnswerFileName), GENERIC_READ, FILE_SHARE_READ, @SecureAttr, OPEN_EXISTING, 0, 0);
          if hInputFileHandle = INVALID_HANDLE_VALUE then
            raise Exception.CreateFmt('Unable to open answer file "%s" for reading: %s', [InputFileName, SysErrorMessage(GetLastError)]);
        end
        else
          hAnswerFileHandle := INVALID_HANDLE_VALUE;

        try
          fResult := fSandBox.Run(hInputFileHandle, hOutputPipeHandleWrite);

          if fResult = RESULT_AC then
          begin
            CloseHandle(hOutputPipeHandleWrite);
            hOutputPipeHandleWrite := INVALID_HANDLE_VALUE;
            SetFilePointer(hInputFileHandle, 0, nil, FILE_BEGIN);

            fResult := fChecker.Run(hInputFileHandle, hOutputPipeHandleRead, hAnswerFileHandle);
            if fResult <> RESULT_AC then
              fMessage := fChecker.Message;
          end
          else
            fMessage := fSandBox.Message;
        finally
          if hAnswerFileHandle <> INVALID_HANDLE_VALUE then
            CloseHandle(hAnswerFileHandle);
        end;

      finally
        if hOutputPipeHandleWrite <> INVALID_HANDLE_VALUE then
          CloseHandle(hOutputPipeHandleWrite);
        CloseHandle(hOutputPipeHandleRead);
      end;

      CloseHandle(hInputFileHandle);
    end;
  except
    on E: Exception do
    begin
      fMessage := Format('Internal error occured while checking on test %d: %s', [fLastTest, E.Message]);
      fResult := RESULT_IE;
    end;
  end;

end;


end.

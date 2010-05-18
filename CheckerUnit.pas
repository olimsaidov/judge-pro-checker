unit CheckerUnit;

interface

uses
  Windows, SysUtils,
  OptionsUnit, CommonTypesUnit;

type

  TChecker = class(TObject)
  private
    fMessage: string;  
    fCheckerFileName: string;
  public
    constructor Create;
    destructor Destroy; override;
    function Run(StdInput, StdOutput, StdError: THandle): TResult;

    property Message: string read fMessage;
    property CheckerFileName: string write fCheckerFileName;
  end;

implementation

{ TChecker }

constructor TChecker.Create;
begin
  inherited;

end;

destructor TChecker.Destroy;
begin

  inherited;
end;

function TChecker.Run(StdInput, StdOutput, StdError: THandle): TResult;
var
  StartInfo: TStartupInfo;
  ProcInfo: TProcessInformation;
  ProcExitCode: Cardinal;
begin
  try
    Result := RESULT_AC;
    fMessage := '';
    FillChar(StartInfo, SizeOf(StartInfo), 0);
    StartInfo.cb := SizeOf(StartInfo);
    StartInfo.wShowWindow := SW_HIDE;
    StartInfo.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;

    StartInfo.hStdInput := StdInput;
    StartInfo.hStdOutput := StdOutput;
    if StdError <> INVALID_HANDLE_VALUE then
      StartInfo.hStdError := StdError
    else
      StartInfo.hStdError := 0;

    if not CreateProcess(
        PChar(fCheckerFileName),
        nil, nil, nil, True, 0, nil,
        PChar(Options.WorkDirectory),
        StartInfo, ProcInfo) then
      raise Exception.CreateFmt('Unable to run checker "%s": %s', [fCheckerFileName, SysErrorMessage(GetLastError())]);

    try
      if WaitForSingleObject(ProcInfo.hProcess, 15000) = WAIT_TIMEOUT then
      begin
        TerminateProcess(ProcInfo.hProcess, 0);
        raise Exception.Create('Run time limit of the checker program exceeded');
      end;

      GetExitCodeProcess(ProcInfo.hProcess, ProcExitCode);

      if not (ProcExitCode in [0, 1, 2, 3]) then
        raise Exception.CreateFmt('Checker program terminated with unexpected exit code: %d', [ProcExitCode]);

      if TResult(ProcExitCode) = RESULT_IE then
        fMessage := 'Checker program reported an internal error';

      Result := TResult(ProcExitCode);
    finally
      CloseHandle(ProcInfo.hProcess);
      CloseHandle(ProcInfo.hThread);
    end;
  except
    on E: Exception do
    begin
      Result := RESULT_IE;
      fMessage := Format('Internal error occured while executing checker: %s', [E.Message]);
    end;
  end;
end;

end.

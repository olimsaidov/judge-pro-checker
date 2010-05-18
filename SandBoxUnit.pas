unit SandBoxUnit;

interface

uses
  Windows, SysUtils, JwaWindows,
  OptionsUnit, CommonTypesUnit;

type
  TSandBox = class(TObject)
  private
    fRunTime: Cardinal;
    fMessage: string;
    fMemoryUsage: Cardinal;
    fTimeLimit: Cardinal;
    fMemoryLimit: Cardinal;
    fExecutableFileName: string;
    fCommandLine: string;
    fWorkDirectory: string;
  public
    constructor Create;
    destructor Destroy; override;
    function Run(StdInput, StdOutput: THandle): TResult;

    property Message: string read fMessage;
    property RunTime: Cardinal read fRunTime;
    property MemoryUsage: Cardinal read fMemoryUsage;
    property MemoryLimit: Cardinal write fMemoryLimit;
    property TimeLimit: Cardinal write fTimeLimit;
    property ExecutableFileName: string write fExecutableFileName;
    property CommandLine: string write fCommandLine;
    property WorkDirectory: string write fWorkDirectory;
  end;

implementation

{ TSandbox }

constructor TSandBox.Create;
begin

end;

destructor TSandBox.Destroy;
begin

  inherited;
end;

function TSandbox.Run(StdInput, StdOutput: THandle): TResult;
var
  StartInfoW: TStartupInfo;
  ProcInfo: TProcessInformation;
  RunTime: Cardinal;
  CreationTime, ExitTime, KernelTime, UserTime: TFileTime;
  ProcExitCode: Cardinal;
  ProcMemCounter: TProcessMemoryCounters;
begin
  try
    Result := RESULT_AC;

    FillChar(StartInfoW, SizeOf(StartInfoW), 0);
    StartInfoW.cb := SizeOf(StartInfoW);
    StartInfoW.wShowWindow := SW_HIDE;
    StartInfoW.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
    StartInfoW.hStdOutput := StdOutput;
    StartInfoW.hStdInput := StdInput;
    StartInfoW.hStdError := StdOutput;

    if not  CreateProcessWithLogonW(
        PChar(Options.RestrictedUserName), nil,
        PChar(Options.RestrictedUserPassword), 0,
        PChar(fExecutableFileName),
        PChar(fCommandLine), 0, nil,
        PChar(fWorkDirectory),
        StartInfoW, ProcInfo) then
      raise Exception.CreateFmt('Unable to create process "%s" with command line "%s": %s', [fExecutableFileName, fCommandLine, SysErrorMessage(GetLastError)]);

    try

      if WaitForSingleObject(ProcInfo.hProcess, fTimeLimit * 5) = WAIT_TIMEOUT then
      begin
        TerminateProcess(ProcInfo.hProcess, 0);
        Result :=  RESULT_TL;
        fRunTime := fTimeLimit;
      end;

      if Result = RESULT_AC then
      begin
        if not GetProcessTimes(ProcInfo.hProcess, CreationTime, ExitTime, KernelTime, UserTime) then
          raise Exception.CreateFmt('Unable to get time information of the process: %s', [SysErrorMessage(GetLastError())]);

        RunTime := (int64(KernelTime.dwLowDateTime or (KernelTime.dwHighDateTime shr 32)) + int64(UserTime.dwLowDateTime or (UserTime.dwHighDateTime shr 32))) div 10000;
        if RunTime > fRunTime then
          fRunTime := RunTime;
        if fRunTime > fTimeLimit then
          Result :=  RESULT_TL;
      end;

      if Result = RESULT_AC then
      begin
        GetExitCodeProcess(ProcInfo.hProcess, ProcExitCode);
        if ProcExitCode <> 0 then
        begin
          Result := RESULT_RE;
          fMessage := 'Process finished with exit code ' + IntToStr(ProcExitCode);
        end;
      end;

      if Result = RESULT_AC then
      begin
        ProcMemCounter.cb := SizeOf(ProcMemCounter);
        if not GetProcessMemoryInfo(ProcInfo.hProcess, ProcMemCounter, SizeOf(ProcMemCounter)) then
          raise Exception.CreateFmt('Unable to get memory information of the process: %s', [SysErrorMessage(GetLastError())]);

        fMemoryUsage := ProcMemCounter.PeakWorkingSetSize;
        if fMemoryUsage > fMemoryLimit then
          Result := RESULT_ML;
      end;

    finally
      CloseHandle(ProcInfo.hProcess);
      CloseHandle(ProcInfo.hThread);
    end;
  except
    on E: Exception do
    begin
      Result := RESULT_IE;
      fMessage := Format('Internal error occured while executing solution: %s', [E.Message]);
    end;
  end;
end;

end.

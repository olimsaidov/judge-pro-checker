unit CompilerUnit;

interface

uses
  Windows, SysUtils, Classes, StrUtils,
  OptionsUnit, CommonTypesUnit;

type

  TCompiler = class(TObject)
  private
    fCompilationTimeLimit: Integer;
    fSourceFileName: string;
    fMessage: string;
    fCompilerPath: string;
    fCompilerCommandLine: string;
    fId: Integer;
    fExecutableFileName: string;
    fExecutableCommandLine: string;
    fLanguageName: string;
    fWorkDirectory: string;
    procedure WorkDirectorySetter(const NewWorkDirectory: string); virtual;
  protected
    procedure Assign(Source: TCompiler); virtual;
  public
    function Compile(const SourceFile: TBytes): TResult; virtual; abstract;
    constructor Create(Source: TCompiler = nil);

    property Message: string read fMessage;
    property Id: Integer read fId;
    property ExecutableFileName: string read fExecutableFileName;
    property ExecutableCommandLine: string read fExecutableCommandLine;
    property LanguageName: string read fLanguageName;
    property WorkDirectory: string write WorkDirectorySetter;

  end;

  TMyCharArray = array [0..High(Integer) - 1] of AnsiChar;
  PMyCharArray = ^TMyCharArray;

  TPascalLanguage = class(TCompiler)
  private
    procedure WorkDirectorySetter(const NewWorkDirectory: string); override;
  public
    constructor Create(Source: TPascalLanguage = nil);
    function Compile(const SourceFile: TBytes): TResult; override;
    procedure Assign(Source: TPascalLanguage); reintroduce;
  end;

  TCLanguage = class(TCompiler)
  private
    procedure WorkDirectorySetter(const NewWorkDirectory: string); override;
  public
    constructor Create(Source: TCLanguage = nil);
    function Compile(const SourceFile: TBytes): TResult; override;
    procedure Assign(Source: TCLanguage); reintroduce;
  end;

  TCppLanguage = class(TCompiler)
  private
    procedure WorkDirectorySetter(const NewWorkDirectory: string); override;
  public
    constructor Create(Source: TCppLanguage = nil);
    function Compile(const SourceFile: TBytes): TResult; override;
    procedure Assign(Source: TCppLanguage); reintroduce;
  end;

  TCsharpLanguage = class(TCompiler)
  private
    procedure WorkDirectorySetter(const NewWorkDirectory: string); override;
  public
    constructor Create(Source: TCsharpLanguage = nil);
    function Compile(const SourceFile: TBytes): TResult; override;
    procedure Assign(Source: TCsharpLanguage); reintroduce;
  end;

  TJavaLanguage = class(TCompiler)
  private
    fJvmPath: string;
    fJvmCommandLine: string;
    procedure WorkDirectorySetter(const NewWorkDirectory: string); override;
  public
    constructor Create(Source: TJavaLanguage = nil);
    function Compile(const SourceFile: TBytes): TResult; override;
    procedure Assign(Source: TJavaLanguage); reintroduce;
  end;

  TCompilerCollection = class(TObject)
  private
    fPascalLanguage: TPascalLanguage;
    fCLanguage: TCLanguage;
    fCppLanguage: TCppLanguage;
    fCsharpLanguage: TCsharpLanguage;
    fJavaLanguage: TJavaLanguage;
    function GetCompiler(Language: Integer): TCompiler;
  public
    constructor Create;
    destructor Destroy; override;

    property CreateCompiler[Index: Integer]: TCompiler read GetCompiler; default;
  end;

var
  CompilerCollection: TCompilerCollection;

implementation

{$REGION 'Compilers definitions'}

{$ENDREGION}


{ TPascalLanguage }

procedure TPascalLanguage.Assign(Source: TPascalLanguage);
begin
  inherited Assign(Source);
end;

function TPascalLanguage.Compile(const SourceFile: TBytes): TResult;
var
  StartInfo: STARTUPINFO;
  ProcInfo: PROCESS_INFORMATION;
  SecureAttr: SECURITY_ATTRIBUTES;
  ProcExitCode: Cardinal;
  hReadOut, hWriteOut: THANDLE;
  Buffer: PMyCharArray;
  dwFileSize: DWORD;
  dwBytesRead: Dword;
  FileStream: TFileStream;

  PreamblePos: Integer;
  SourceEncoding: TEncoding;
  EncodedSourceFile: TBytes;
begin
  try
    SourceEncoding := nil;
    PreamblePos := TEncoding.GetBufferEncoding(SourceFile, SourceEncoding);
    EncodedSourceFile := TEncoding.Convert(SourceEncoding,
      TEncoding.UTF8, SourceFile, PreamblePos, Length(SourceFile) - PreamblePos);
    FileStream := TFileStream.Create(fSourceFileName, fmCreate, fmShareExclusive);
    try
      FileStream.Write(EncodedSourceFile[0], Length(EncodedSourceFile));
    finally
      FileStream.Free;
    end;
    SetLength(EncodedSourceFile, 0);

    Result := RESULT_AC;

    SecureAttr.nLength := SizeOf(SecureAttr);
    SecureAttr.lpSecurityDescriptor := nil;
    SecureAttr.bInheritHandle := True;

    if not CreatePipe(hReadOut, hWriteOut, @SecureAttr, 1 * 1024 * 1024 * 10) then
      raise Exception.Create('Unable to create pipe for compiler''s output');

    try

      FillChar(StartInfo, SizeOf(StartInfo), 0);
      StartInfo.cb := SizeOf(StartInfo);
      StartInfo.wShowWindow := SW_HIDE;
      StartInfo.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
      StartInfo.hStdOutput := hWriteOut;
      StartInfo.hStdError := hWriteOut;

      if not CreateProcess(
          PChar(fCompilerPath),
          PChar(Format(fCompilerCommandLine, [fCompilerPath, fSourceFileName])),
          nil, nil, True, 0, nil,
          PChar(fWorkDirectory),
          StartInfo, ProcInfo) then
        raise Exception.CreateFmt('Unable to run compiler "%s"', [fCompilerPath]);

      try
        if WaitForSingleObject(ProcInfo.hProcess, fCompilationTimeLimit) = WAIT_TIMEOUT then //wait untill compilation finished
        begin
          TerminateProcess(ProcInfo.hProcess, 1);
          raise Exception.CreateFmt('Timeout while compiling "%s"', [fSourceFileName]);
        end;

        GetExitCodeProcess(ProcInfo.hProcess, ProcExitCode);
        CloseHandle(hWriteOut);
        hWriteOut := INVALID_HANDLE_VALUE;

        if ProcExitCode <> 0 then
        begin
          Result := RESULT_CE;
          dwFileSize := GetFileSize(hReadOut, nil);
          GetMem(Buffer, dwFileSize);

          try
            if dwFileSize <> 0 then
              if (not ReadFile(hReadOut, Buffer^, dwFileSize, dwBytesRead, nil) or (dwFileSize <> dwBytesRead)) then
                raise Exception.Create('Unable to read data from compiler''s output pipe. ' + SysErrorMessage(GetLastError));

            Buffer^[dwBytesRead] := Char(0);
            fMessage := string(Buffer^);
          finally
            FreeMem(Buffer);
          end;
        end;

      finally
        CloseHandle(ProcInfo.hProcess);
        CloseHandle(ProcInfo.hThread);
      end;

    finally
      if hWriteOut <> INVALID_HANDLE_VALUE then
        CloseHandle(hWriteOut);
      CloseHandle(hReadOut);
    end;

  except
    on E: Exception do
    begin
      Result := RESULT_IE;
      fMessage := Format('Internal error occured while compiling: %s', [E.Message]);
    end;
  end;

end;

constructor TPascalLanguage.Create;
begin
  if Source <> nil then
    Self.Assign(Source)
  else
  begin
    fLanguageName := 'Pascal';
    fId := Options[fLanguageName, 'Id'];
    fCompilerPath := Options[fLanguageName, 'Path'];
    fCompilerCommandLine := Options[fLanguageName, 'CommandLine'];
    fCompilationTimeLimit := Options[fLanguageName, 'CompilationTimeLimit'];

    fExecutableCommandLine := '';
  end;
end;

procedure TPascalLanguage.WorkDirectorySetter(const NewWorkDirectory: string);
begin
  inherited WorkDirectorySetter(NewWorkDirectory);
  fSourceFileName := fWorkDirectory + 'solution.pas';
  fExecutableFileName := fWorkDirectory + 'solution.exe';
end;

{ TCLanguage }

procedure TCLanguage.Assign(Source: TCLanguage);
begin
  inherited Assign(Source);
end;

function TCLanguage.Compile(const SourceFile: TBytes): TResult;
var
  StartInfo: STARTUPINFO;
  ProcInfo: PROCESS_INFORMATION;
  SecureAttr: SECURITY_ATTRIBUTES;
  ProcExitCode: Cardinal;
  hReadOut, hWriteOut: THANDLE;
  Buffer: PMyCharArray;
  dwFileSize: DWORD;
  dwBytesRead: Dword;
  FileStream: TFileStream;

  PreamblePos: Integer;
  SourceEncoding: TEncoding;
  EncodedSourceFile: TBytes;
begin
  try
    SourceEncoding := nil;
    PreamblePos := TEncoding.GetBufferEncoding(SourceFile, SourceEncoding);
    EncodedSourceFile := TEncoding.Convert(SourceEncoding,
      TEncoding.UTF8, SourceFile, PreamblePos, Length(SourceFile) - PreamblePos);
    FileStream := TFileStream.Create(fSourceFileName, fmCreate, fmShareExclusive);
    try
      FileStream.Write(EncodedSourceFile[0], Length(EncodedSourceFile));
    finally
      FileStream.Free;
    end;
    SetLength(EncodedSourceFile, 0);

    Result := RESULT_AC;

    SecureAttr.nLength := SizeOf(SecureAttr);
    SecureAttr.lpSecurityDescriptor := nil;
    SecureAttr.bInheritHandle := True;

    if not CreatePipe(hReadOut, hWriteOut, @SecureAttr, 1 * 1024 * 1024 * 10) then
      raise Exception.Create('Unable to create pipe for compiler''s output');

    try

      FillChar(StartInfo, SizeOf(StartInfo), 0);
      StartInfo.cb := SizeOf(StartInfo);
      StartInfo.wShowWindow := SW_HIDE;
      StartInfo.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
      StartInfo.hStdOutput := hWriteOut;
      StartInfo.hStdError := hWriteOut;

      if not CreateProcess(
          PChar(fCompilerPath),
          PChar(Format(fCompilerCommandLine, [fCompilerPath, fSourceFileName])),
          nil, nil, True, 0, nil,
          PChar(fWorkDirectory),
          StartInfo, ProcInfo) then
        raise Exception.CreateFmt('Unable to run compiler "%s"', [fCompilerPath]);

      try
        if WaitForSingleObject(ProcInfo.hProcess, fCompilationTimeLimit) = WAIT_TIMEOUT then //wait untill compilation finished
        begin
          TerminateProcess(ProcInfo.hProcess, 1);
          raise Exception.CreateFmt('Timeout while compiling "%s"', [fSourceFileName]);
        end;

        GetExitCodeProcess(ProcInfo.hProcess, ProcExitCode);
        CloseHandle(hWriteOut);
        hWriteOut := INVALID_HANDLE_VALUE;

        if ProcExitCode <> 0 then
        begin
          Result := RESULT_CE;
          dwFileSize := GetFileSize(hReadOut, nil);
          GetMem(Buffer, dwFileSize);

          try
            if dwFileSize <> 0 then
              if (not ReadFile(hReadOut, Buffer^, dwFileSize, dwBytesRead, nil) or (dwFileSize <> dwBytesRead)) then
                raise Exception.Create('Unable to read data from compiler''s output pipe. ' + SysErrorMessage(GetLastError));

            Buffer^[dwBytesRead] := Char(0);
            fMessage := string(Buffer^);
          finally
            FreeMem(Buffer);
          end;
        end;

      finally
        CloseHandle(ProcInfo.hProcess);
        CloseHandle(ProcInfo.hThread);
      end;

    finally
      if hWriteOut <> INVALID_HANDLE_VALUE then
        CloseHandle(hWriteOut);
      CloseHandle(hReadOut);
    end;

  except
    on E: Exception do
    begin
      Result := RESULT_IE;
      fMessage := Format('Internal error occured while compiling: %s', [E.Message]);
    end;
  end;

end;

constructor TCLanguage.Create;
begin
  if Source <> nil then
    Self.Assign(Source)
  else
  begin
    fLanguageName := 'C';
    fId := Options[fLanguageName, 'Id'];
    fCompilerPath := Options[fLanguageName, 'Path'];
    fCompilerCommandLine := Options[fLanguageName, 'CommandLine'];
    fCompilationTimeLimit := Options[fLanguageName, 'CompilationTimeLimit'];
    fExecutableCommandLine := '';
  end;
end;

procedure TCLanguage.WorkDirectorySetter(const NewWorkDirectory: string);
begin
  inherited WorkDirectorySetter(NewWorkDirectory);
  fSourceFileName := fWorkDirectory + 'solution.c';
  fExecutableFileName := fWorkDirectory + 'a.exe';
end;

{ TCppLanguage }

procedure TCppLanguage.Assign(Source: TCppLanguage);
begin
  inherited Assign(Source);
end;

function TCppLanguage.Compile(const SourceFile: TBytes): TResult;
var
  StartInfo: STARTUPINFO;
  ProcInfo: PROCESS_INFORMATION;
  SecureAttr: SECURITY_ATTRIBUTES;
  ProcExitCode: Cardinal;
  hReadOut, hWriteOut: THANDLE;
  Buffer: PMyCharArray;
  dwFileSize: DWORD;
  dwBytesRead: Dword;
  FileStream: TFileStream;

  PreamblePos: Integer;
  SourceEncoding: TEncoding; //TODO: Free That
  EncodedSourceFile: TBytes;
begin
  try
    SourceEncoding := nil;
    PreamblePos := TEncoding.GetBufferEncoding(SourceFile, SourceEncoding);
    EncodedSourceFile := TEncoding.Convert(SourceEncoding,
      TEncoding.UTF8, SourceFile, PreamblePos, Length(SourceFile) - PreamblePos);
    FileStream := TFileStream.Create(fSourceFileName, fmCreate, fmShareExclusive);
    try
      FileStream.Write(EncodedSourceFile[0], Length(EncodedSourceFile));
    finally
      FileStream.Free;
    end;
    SetLength(EncodedSourceFile, 0);

    Result := RESULT_AC;

    SecureAttr.nLength := SizeOf(SecureAttr);
    SecureAttr.lpSecurityDescriptor := nil;
    SecureAttr.bInheritHandle := True;

    if not CreatePipe(hReadOut, hWriteOut, @SecureAttr, 1 * 1024 * 1024 * 10) then
      raise Exception.Create('Unable to create pipe for compiler''s output');

    try

      FillChar(StartInfo, SizeOf(StartInfo), 0);
      StartInfo.cb := SizeOf(StartInfo);
      StartInfo.wShowWindow := SW_HIDE;
      StartInfo.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
      StartInfo.hStdOutput := hWriteOut;
      StartInfo.hStdError := hWriteOut;

      if not CreateProcess(
          PChar(fCompilerPath),
          PChar(Format(fCompilerCommandLine, [fCompilerPath, fSourceFileName])),
          nil, nil, True, 0, nil,
          PChar(fWorkDirectory),
          StartInfo, ProcInfo) then
        raise Exception.CreateFmt('Unable to run compiler "%s"', [fCompilerPath]);

      try
        if WaitForSingleObject(ProcInfo.hProcess, fCompilationTimeLimit) = WAIT_TIMEOUT then //wait untill compilation finished
        begin
          TerminateProcess(ProcInfo.hProcess, 1);
          raise Exception.CreateFmt('Timeout while compiling "%s"', [fSourceFileName]);
        end;

        GetExitCodeProcess(ProcInfo.hProcess, ProcExitCode);
        CloseHandle(hWriteOut);
        hWriteOut := INVALID_HANDLE_VALUE;

        if ProcExitCode <> 0 then
        begin
          Result := RESULT_CE;
          dwFileSize := GetFileSize(hReadOut, nil);
          GetMem(Buffer, dwFileSize);

          try
            if dwFileSize <> 0 then
              if (not ReadFile(hReadOut, Buffer^, dwFileSize, dwBytesRead, nil) or (dwFileSize <> dwBytesRead)) then
                raise Exception.Create('Unable to read data from compiler''s output pipe. ' + SysErrorMessage(GetLastError));

            Buffer^[dwBytesRead] := Char(0);
            fMessage := string(Buffer^);
          finally
            FreeMem(Buffer);
          end;
        end;

      finally
        CloseHandle(ProcInfo.hProcess);
        CloseHandle(ProcInfo.hThread);
      end;

    finally
      if hWriteOut <> INVALID_HANDLE_VALUE then
        CloseHandle(hWriteOut);
      CloseHandle(hReadOut);
    end;

  except
    on E: Exception do
    begin
      Result := RESULT_IE;
      fMessage := Format('Internal error occured while compiling: %s', [E.Message]);
    end;
  end;

end;

constructor TCppLanguage.Create;
begin
  if Source <> nil then
    Self.Assign(Source)
  else
  begin
    fLanguageName := 'Cpp';
    fId := Options[fLanguageName, 'Id'];
    fCompilerPath := Options[fLanguageName, 'Path'];
    fCompilerCommandLine := Options[fLanguageName, 'CommandLine'];
    fCompilationTimeLimit := Options[fLanguageName, 'CompilationTimeLimit'];
    fExecutableCommandLine := '';
  end;
end;

procedure TCppLanguage.WorkDirectorySetter(const NewWorkDirectory: string);
begin
  inherited WorkDirectorySetter(NewWorkDirectory);
  fSourceFileName := fWorkDirectory + 'solution.cpp';
  fExecutableFileName := fWorkDirectory + 'a.exe';
end;

{ TCsharp }

procedure TCsharpLanguage.Assign(Source: TCsharpLanguage);
begin
  inherited Assign(Source);
end;

function TCsharpLanguage.Compile(const SourceFile: TBytes): TResult;
var
  StartInfo: STARTUPINFO;
  ProcInfo: PROCESS_INFORMATION;
  SecureAttr: SECURITY_ATTRIBUTES;
  ProcExitCode: Cardinal;
  hReadOut, hWriteOut: THANDLE;
  Buffer: PMyCharArray;
  dwFileSize: DWORD;
  dwBytesRead: Dword;
  FileStream: TFileStream;

  PreamblePos: Integer;
  SourceEncoding: TEncoding;
  EncodedSourceFile: TBytes;
begin
  try
    SourceEncoding := nil;
    PreamblePos := TEncoding.GetBufferEncoding(SourceFile, SourceEncoding);
    EncodedSourceFile := TEncoding.Convert(SourceEncoding,
      TEncoding.UTF8, SourceFile, PreamblePos, Length(SourceFile) - PreamblePos);
    FileStream := TFileStream.Create(fSourceFileName, fmCreate, fmShareExclusive);
    try
      FileStream.Write(EncodedSourceFile[0], Length(EncodedSourceFile));
    finally
      FileStream.Free;
    end;
    SetLength(EncodedSourceFile, 0);

    Result := RESULT_AC;

    SecureAttr.nLength := SizeOf(SecureAttr);
    SecureAttr.lpSecurityDescriptor := nil;
    SecureAttr.bInheritHandle := True;

    if not CreatePipe(hReadOut, hWriteOut, @SecureAttr, 1 * 1024 * 1024 * 10) then
      raise Exception.Create('Unable to create pipe for compiler''s output');

    try

      FillChar(StartInfo, SizeOf(StartInfo), 0);
      StartInfo.cb := SizeOf(StartInfo);
      StartInfo.wShowWindow := SW_HIDE;
      StartInfo.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
      StartInfo.hStdOutput := hWriteOut;
      StartInfo.hStdError := hWriteOut;

      if not CreateProcess(
          PChar(fCompilerPath),
          PChar(Format(fCompilerCommandLine, [fCompilerPath, fSourceFileName])),
          nil, nil, True, 0, nil,
          PChar(fWorkDirectory),
          StartInfo, ProcInfo) then
        raise Exception.CreateFmt('Unable to run compiler "%s"', [fCompilerPath]);

      try
        if WaitForSingleObject(ProcInfo.hProcess, fCompilationTimeLimit) = WAIT_TIMEOUT then //wait untill compilation finished
        begin
          TerminateProcess(ProcInfo.hProcess, 1);
          raise Exception.CreateFmt('Timeout while compiling "%s"', [fSourceFileName]);
        end;

        GetExitCodeProcess(ProcInfo.hProcess, ProcExitCode);
        CloseHandle(hWriteOut);
        hWriteOut := INVALID_HANDLE_VALUE;

        if ProcExitCode <> 0 then
        begin
          Result := RESULT_CE;
          dwFileSize := GetFileSize(hReadOut, nil);
          GetMem(Buffer, dwFileSize);

          try
            if dwFileSize <> 0 then
              if (not ReadFile(hReadOut, Buffer^, dwFileSize, dwBytesRead, nil) or (dwFileSize <> dwBytesRead)) then
                raise Exception.Create('Unable to read data from compiler''s output pipe. ' + SysErrorMessage(GetLastError));

            Buffer^[dwBytesRead] := Char(0);
            fMessage := string(Buffer^);
          finally
            FreeMem(Buffer);
          end;
        end;

      finally
        CloseHandle(ProcInfo.hProcess);
        CloseHandle(ProcInfo.hThread);
      end;

    finally
      if hWriteOut <> INVALID_HANDLE_VALUE then
        CloseHandle(hWriteOut);
      CloseHandle(hReadOut);
    end;

  except
    on E: Exception do
    begin
      Result := RESULT_IE;
      fMessage := Format('Internal error occured while compiling: %s', [E.Message]);
    end;
  end;
end;

constructor TCsharpLanguage.Create;
begin
  if Source <> nil then
    Self.Assign(Source)
  else
  begin
    fLanguageName := 'Csharp';
    fId := Options[fLanguageName, 'Id'];
    fCompilerPath := Options[fLanguageName, 'Path'];
    fCompilerCommandLine := Options[fLanguageName, 'CommandLine'];
    fCompilationTimeLimit := Options[fLanguageName, 'CompilationTimeLimit'];
    fExecutableCommandLine := '';
  end;
end;

procedure TCsharpLanguage.WorkDirectorySetter(const NewWorkDirectory: string);
begin
  inherited WorkDirectorySetter(NewWorkDirectory);
  fSourceFileName := fWorkDirectory + 'solution.cs';
  fExecutableFileName := fWorkDirectory + 'solution.exe';
end;

{ TJavaLanguage }

procedure TJavaLanguage.Assign(Source: TJavaLanguage);
begin
  inherited Assign(Source);
  Self.fJvmPath := Source.fJvmPath;
  Self.fJvmCommandLine := Source.fJvmCommandLine;
end;

function TJavaLanguage.Compile(const SourceFile: TBytes): TResult;
var
  StartInfo: STARTUPINFO;
  ProcInfo: PROCESS_INFORMATION;
  SecureAttr: SECURITY_ATTRIBUTES;
  ProcExitCode: Cardinal;
  hReadOut, hWriteOut: THANDLE;
  Buffer: PMyCharArray;
  dwFileSize: DWORD;
  dwBytesRead: Dword;
  posNameStart, posNameEnd: integer;
  NewSourceFileName: string;
  FileStream: TFileStream;

  PreamblePos: Integer;
  SourceEncoding: TEncoding;
  EncodedSourceFile: TBytes;
begin
  try
    SourceEncoding := nil;
    PreamblePos := TEncoding.GetBufferEncoding(SourceFile, SourceEncoding);
    EncodedSourceFile := TEncoding.Convert(SourceEncoding,
      TEncoding.UTF8, SourceFile, PreamblePos, Length(SourceFile) - PreamblePos);
    FileStream := TFileStream.Create(fSourceFileName, fmCreate, fmShareExclusive);
    try
      FileStream.Write(EncodedSourceFile[0], Length(EncodedSourceFile));
    finally
      FileStream.Free;
    end;
    SetLength(EncodedSourceFile, 0);

    Result := RESULT_AC;

    SecureAttr.nLength := SizeOf(SecureAttr);
    SecureAttr.lpSecurityDescriptor := nil;
    SecureAttr.bInheritHandle := True;

    if not CreatePipe(hReadOut, hWriteOut, @SecureAttr, 1 * 1024 * 1024 * 10) then
      raise Exception.Create('Unable to create pipe for compiler''s output');

    try

      FillChar(StartInfo, SizeOf(StartInfo), 0);
      StartInfo.cb := SizeOf(StartInfo);
      StartInfo.wShowWindow := SW_HIDE;
      StartInfo.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
      StartInfo.hStdOutput := hWriteOut;
      StartInfo.hStdError := hWriteOut;

      if not CreateProcess(
          PChar(fCompilerPath),
          PChar(Format(fCompilerCommandLine, [fCompilerPath, fSourceFileName])),
          nil, nil, True, 0, nil,
          PChar(fWorkDirectory),
          StartInfo, ProcInfo) then
        raise Exception.CreateFmt('Unable to run compiler "%s"', [fCompilerPath]);

      try
        if WaitForSingleObject(ProcInfo.hProcess, fCompilationTimeLimit) = WAIT_TIMEOUT then //wait untill compilation finished
        begin
          TerminateProcess(ProcInfo.hProcess, 1);
          raise Exception.CreateFmt('Timeout while compiling "%s"', [fSourceFileName]);
        end;

        GetExitCodeProcess(ProcInfo.hProcess, ProcExitCode);
        CloseHandle(hWriteOut);
        hWriteOut := INVALID_HANDLE_VALUE;

        if ProcExitCode <> 0 then
        begin
          dwFileSize := GetFileSize(hReadOut, nil);
          GetMem(Buffer, dwFileSize);

          try
            if dwFileSize <> 0 then
              if (not ReadFile(hReadOut, Buffer^, dwFileSize, dwBytesRead, nil) or (dwFileSize <> dwBytesRead)) then
                raise Exception.Create('Unable to read data from compiler''s output pipe. ' + SysErrorMessage(GetLastError));

            Buffer^[dwBytesRead] := Char(0);
            fMessage := string(Buffer^);
          finally
            FreeMem(Buffer);
          end;

          if Pos(JAVA_FILE_MUST_BE_RENAMED, fMessage) <> 0 then //We should chanage the *.java name to class name
          begin
            Result := RESULT_CE;
            posNameStart := Pos(JAVA_FILE_MUST_BE_RENAMED, fMessage) + Length(JAVA_FILE_MUST_BE_RENAMED);
            posNameEnd := PosEx(#13#10, fMessage, posNameStart);

            NewSourceFileName := fWorkDirectory + Copy(fMessage, posNameStart, PosNameEnd - PosNameStart);

            if not SysUtils.DeleteFile(fSourceFileName) then
              raise Exception.CreateFmt('Unable to remove the source file %s: %s', [fSourceFileName, SysErrorMessage(GetLastError())]);

            fSourceFileName := NewSourceFileName;
            Result := Self.Compile(SourceFile);
            fExecutableCommandLine := Format(fJvmCommandLine, [fJvmPath, ReplaceText(ExtractFileName(fSourceFileName), '.java', '')]);
          end
          else
            Result := RESULT_CE;
        end;

      finally
        CloseHandle(ProcInfo.hProcess);
        CloseHandle(ProcInfo.hThread);
      end;

    finally
      if hWriteOut <> INVALID_HANDLE_VALUE then
        CloseHandle(hWriteOut);
      CloseHandle(hReadOut);
    end;

  except
    on E: Exception do
    begin
      Result := RESULT_IE;
      fMessage := Format('Internal error occured while compiling: %s', [E.Message]);
    end;
  end;
end;

constructor TJavaLanguage.Create;
begin
  if Source <> nil then
    Self.Assign(Source)
  else
  begin
    fLanguageName := 'Java';
    fId := Options[fLanguageName, 'Id'];
    fCompilerPath := Options[fLanguageName, 'Path'];
    fCompilerCommandLine := Options[fLanguageName, 'CommandLine'];
    fCompilationTimeLimit := Options[fLanguageName, 'CompilationTimeLimit'];
    fJvmPath := Options[fLanguageName, 'JvmPath'];
    fJvmCommandLine := Options[fLanguageName, 'JvmCommandLine'];
    fExecutableFileName := fJvmPath;
  end;
end;

procedure TJavaLanguage.WorkDirectorySetter(const NewWorkDirectory: string);
begin
  inherited WorkDirectorySetter(NewWorkDirectory);
  fSourceFileName :=  fWorkDirectory + 'solution.java';
end;

{ TCompilerCollection }

constructor TCompilerCollection.Create;
begin
  if Options.SectionExists('Pascal') then
    fPascalLanguage := TPascalLanguage.Create;

  if Options.SectionExists('C') then
    fCLanguage := TCLanguage.Create;

  if Options.SectionExists('Cpp') then
    fCppLanguage := TCppLanguage.Create;

  if Options.SectionExists('Java') then
    fJavaLanguage := TJavaLanguage.Create;

  if Options.SectionExists('Csharp') then
    fCsharpLanguage := TCsharpLanguage.Create;
end;

destructor TCompilerCollection.Destroy;
begin
  fPascalLanguage.Free;
  fCLanguage.Free;
  fCppLanguage.Free;
  fCsharpLanguage.Free;
  fJavaLanguage.Free;
  inherited;
end;

function TCompilerCollection.GetCompiler(Language: Integer): TCompiler;
begin
  if (fPascalLanguage <> nil) and (fPascalLanguage.Id = Language) then
    Result := TPascalLanguage.Create(fPascalLanguage)
  else if (fCLanguage <> nil) and (fCLanguage.Id = Language) then
    Result := TCLanguage.Create(fCLanguage)
  else if (fCppLanguage <> nil) and (fCppLanguage.Id = Language) then
    Result := TCppLanguage.Create(fCppLanguage)
  else if (fCsharpLanguage <> nil) and (fCsharpLanguage.Id = Language) then
    Result := TCsharpLanguage.Create(fCsharpLanguage)
  else if (fJavaLanguage <> nil) and (fJavaLanguage.Id = Language) then
    Result := TJavaLanguage.Create(fJavaLanguage)
  else
    raise Exception.CreateFmt('Language with id: %d does not exists', [Language]);
end;

{ TCompiler }

procedure TCompiler.Assign(Source: TCompiler);
begin
  Self.fCompilerPath := Source.fCompilerPath;
  Self.fCompilerCommandLine := Source.fCompilerCommandLine;
  Self.fCompilationTimeLimit := Source.fCompilationTimeLimit;
  Self.fSourceFileName := Source.fSourceFileName;
  Self.fExecutableFileName := Source.fExecutableFileName;
  Self.fExecutableCommandLine := Source.fExecutableCommandLine;
  Self.fId := Source.fId;
  Self.fLanguageName := Source.fLanguageName;
end;

constructor TCompiler.Create(Source: TCompiler);
begin

end;

procedure TCompiler.WorkDirectorySetter(const NewWorkDirectory: string);
begin
  fWorkDirectory := NewWorkDirectory;
end;

end.

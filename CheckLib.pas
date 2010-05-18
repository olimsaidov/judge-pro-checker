unit CheckLib;

interface

uses
  Windows, SysUtils;

type
  TCharset = set of char;
  TResult = (_OK = 0, _AC = 0, _WA = 1, _PE = 2, _FAIL = 3);
  TArrayOfChar = array [0..0] of char;
  PArrayOfChar = ^TArrayOfChar;
  
  TStream = class(TObject)
  private
    fHandle: THandle;
    fBuffer: PChar;
    fCursor: Integer;
    fSize: Integer;
    
    procedure FillBuffer;
  public
    fEofChar: Char;
    fEofBlankChars: TCharset;
    fEolnChars: TCharset;
    fEolnBlankChars: TCharset;
    fNumberBefore: TCharset;
    fNumberAfter: TCharset;   
    fLineAfter: TCharset;
    
    constructor Create; virtual; 
    destructor Destroy; override;

    function CurChar(): char;
    function NextChar(): char;
    function Eof(): boolean;
    function SeekEof(): boolean;
    function Eoln(): boolean;
    function SeekEoln(): boolean;

    function ReadWord(Before, After: TCharset): string; virtual;
    function ReadInteger(): Integer; virtual;
    function ReadLongInt(): Integer; virtual;
    function ReadBigInteger(): Int64; virtual;
    function ReadReal(): Extended; virtual;
    function ReadRealFixed(DigitsAfterDot: Integer): Extended; virtual;
    function ReadString(): string; virtual;

    procedure SkipChar();
    procedure Skip(CharsToSkip: TCharset);
    procedure NextLine();
    procedure Reset();
    procedure ShowBuffer();
  end;

  TInputStream = class(TStream)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ReadWord(Before, After: TCharset): string; override;
    function ReadInteger(): Integer; override;
    function ReadLongInt(): Integer; override;
    function ReadBigInteger(): Int64; override;
    function ReadReal(): Extended; override;
    function ReadRealFixed(DigitsAfterDot: Integer): Extended; override;
    function ReadString(): string; override;
  end;

  TAnswerStream = class(TStream)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ReadWord(Before, After: TCharset): string; override;
    function ReadInteger(): Integer; override;
    function ReadLongInt(): Integer; override;
    function ReadBigInteger(): Int64; override;
    function ReadReal(): Extended; override;
    function ReadRealFixed(DigitsAfterDot: Integer): Extended; override;
    function ReadString(): string; override;
  end;

  TOutputStream = class(TStream)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ReadWord(Before, After: TCharset): string; override;
    function ReadInteger(): Integer; override;
    function ReadLongInt(): Integer; override;
    function ReadBigInteger(): Int64; override;
    function ReadReal(): Extended; override;
    function ReadRealFixed(DigitsAfterDot: Integer): Extended; override;
    function ReadString(): string; override;
  end;     

procedure Quit(Result: TResult; ErrorMessage: string);
procedure Quit(Result: TResult);

var
  inf, ouf, ans: TStream;

implementation

procedure Quit(Result: TResult);
begin
  Quit(Result, '');
end;

procedure Quit(Result: TResult; ErrorMessage: string);
begin
  if Result = _AC then
    if not ouf.SeekEof then
      Result := _PE;

  //if ErrorMessage <> '' then
  //  MessageBox(GetDesktopWindow(), PChar(ErrorMessage), 0, $10);
       
  Halt(Ord(Result));
end;

{ TStream }

constructor TStream.Create;
begin
  fEofChar       := #26;
  fEofBlankChars  := [#10, #13, #32, #09];
  fEolnChars      := [#10, #13, #26];
  fEolnBlankChars := [#32, #9];
  fNumberBefore   := [#10, #13, #32, #09];
  fNumberAfter    := [#10, #13, #32, #09, #26];
  fLineAfter      := [#10, #13, #26];
end;

procedure TStream.ShowBuffer();
begin
  MessageBox(0, fBuffer, 'Buffer', 0);
end;

function TStream.CurChar: char;
begin
  Result := fBuffer[fCursor]
end;

destructor TStream.Destroy;
begin
  FreeMem(fBuffer);
  CloseHandle(fHandle);
  inherited;
end;

function TStream.Eof: boolean;
begin
  Result := fBuffer[fCursor] = fEofChar;
end;

function TStream.Eoln: boolean;
begin
  Result := fBuffer[fCursor] in  fEolnChars;
end;

procedure TStream.FillBuffer;
var
  BytesRead: Cardinal;
begin
  if fHandle <> 0 then
  begin
    fSize := GetFileSize(fHandle, nil);
    if fSize = -1 then
      raise Exception.CreateFmt('GetFileSize function failed. Handle is: %d. Reason: %s', [fHandle, SysErrorMessage(GetLastError())]);
  end
  else
    fSize := 0;

  fBuffer := AllocMem(fSize + 1);
  if fSize <> 0 then
    ReadFile(fHandle, fBuffer^, fSize, BytesRead, nil);
  fBuffer[fSize] := fEofChar;
 
  fCursor := 0;
end;

function TStream.NextChar: char;
begin
  Result := CurChar();
  SkipChar();
end;

procedure TStream.NextLine;
begin
  while not (fBuffer[fCursor] in fEolnChars) do
    SkipChar();
  if fBuffer[fCursor] = #13 then
    SkipChar();
  if fBuffer[fCursor] = #10 then
    SkipChar();
end;

function TStream.ReadInteger: Integer;
var 
  Token: string;
begin
  Token := ReadWord(fNumberBefore, fNumberAfter);
  try
    Result := StrToInt(Token);
  except
    raise Exception.CreateFmt('Token is not valid integer number: %s', [Token]);
  end;
end;

function TStream.ReadLongInt: Integer;
var 
  Token: string;
begin
  Token := ReadWord(fNumberBefore, fNumberAfter);
  try
    Result := StrToInt(Token);
  except
    raise Exception.CreateFmt('Token is not valid integer number: %s', [Token]);
  end;
end;

function TStream.ReadBigInteger: Int64;
var 
  Token: string;
begin
  Token := ReadWord(fNumberBefore, fNumberAfter);
  try
    Result := StrToInt64(Token);
  except
    raise Exception.CreateFmt('Token is not valid integer number: %s', [Token]);
  end;
end;

function TStream.ReadReal: Extended;
var 
  Token: string;
begin
  Token := ReadWord(fNumberBefore, fNumberAfter);
  try
    Result := StrToFloat(Token);
  except
    raise Exception.CreateFmt('Token is not valid real number: %s', [Token]);
  end;
end;

function TStream.ReadRealFixed(DigitsAfterDot: Integer): Extended;
var 
  Token: string;
  i: Integer;
begin
  Token := UpperCase(ReadWord(fNumberBefore, fNumberAfter));
  
  for i := 1 to Length(Token) do
    if not (Token[i] in ['0'..'9', DecimalSeparator, '-']) then
      raise Exception.CreateFmt('Wrong character encountered: %s', [Token]);
      
  try
    Result := StrToFloat(Token);
  except
    raise Exception.CreateFmt('Token is not valid real number: %s', [Token]);
  end;

  if Length(Token) - Pos(DecimalSeparator, Token) <> DigitsAfterDot then
    raise Exception.Create('Amount of digits after decimal serepator existing in token differs from requested one');
  
end;

function TStream.ReadString: string;
begin
  Result := Readword([], fLineAfter);
  Nextline();
end;

function TStream.ReadWord(Before, After: TCharset): string;
begin
  while fBuffer[fCursor] in Before do
    SkipChar();

  if (fBuffer[fCursor] = fEofChar) then
    raise Exception.Create('Unexpected end of file is encountered.');

  Result := '';
  while not (fBuffer[fCursor] in After)  do
    Result := Result + NextChar();
end;

procedure TStream.Reset;
begin
  fCursor := 0;
end;

function TStream.SeekEof(): boolean;
begin
  Skip(fEofBlankChars);
  Result := Self.Eof();
end;

function TStream.SeekEoln: boolean;
begin
  Skip(fEolnBlankChars);
  Result := Self.Eoln();
end;

procedure TStream.Skip(CharsToSkip: TCharset);
begin
 while fBuffer[fCursor] in CharsToSkip do
    SkipChar();
end;

procedure TStream.SkipChar;
begin
  if not Self.Eof() then
    inc(fCursor);
end;

{ TInputStream }

constructor TInputStream.Create;
begin
  try
    inherited;
    fHandle := GetStdHandle(STD_INPUT_HANDLE);
    if fHandle = INVALID_HANDLE_VALUE then
      raise Exception.CreateFmt('GetStdHandle function failed: %s', [SysErrorMessage(GetLastError())]);
    
    FillBuffer();
  except
    on E: Exception do
      raise Exception.CreateFmt('Output stream error on creating: %s', [E.Message]);
  end;
end;

destructor TInputStream.Destroy;
begin

  inherited;
end;

function TInputStream.ReadInteger: Integer;
begin
  try
    Result := inherited ReadInteger();
  except
    on E: Exception do
      Quit(_FAIL, E.Message);
  end;
end;

function TInputStream.ReadLongInt: Integer;
begin
  try
    Result := inherited ReadLongInt();
  except
    on E: Exception do
      Quit(_FAIL, E.Message);
  end;
end;

function TInputStream.ReadBigInteger: Int64;
begin
  try
    Result := inherited ReadBigInteger();
  except
    on E: Exception do
      Quit(_FAIL, E.Message);
  end;
end;

function TInputStream.ReadReal: Extended;
begin
  try
    Result := inherited ReadReal();
  except
    on E: Exception do
      Quit(_FAIL, E.Message);
  end;
end;

function TInputStream.ReadRealFixed(DigitsAfterDot: Integer): Extended;
begin
  try
    Result := inherited ReadRealFixed(DigitsAfterDot);
  except
    on E: Exception do
      Quit(_FAIL, E.Message);
  end;
end;

function TInputStream.ReadString: string;
begin
  try
    Result := inherited ReadString();
  except
    on E: Exception do
      Quit(_FAIL, E.Message);
  end;
end;

function TInputStream.ReadWord(Before, After: TCharset): string;
begin
  try
    Result := inherited ReadWord(Before, After);
  except
    on E: Exception do
      Quit(_FAIL, E.Message);
  end;
end;

{ TAnswerStream }

constructor TAnswerStream.Create;
begin
  try
    inherited;
    fHandle := GetStdHandle(STD_ERROR_HANDLE);
    if fHandle = INVALID_HANDLE_VALUE then
      raise Exception.CreateFmt('GetStdHandle function failed: %s', [SysErrorMessage(GetLastError())]);
    FillBuffer();
  except
    on E: Exception do
      raise Exception.CreateFmt('Answer stream error on creating: %s', [E.Message]);
  end;
end;

destructor TAnswerStream.Destroy;
begin

  inherited;
end;

function TAnswerStream.ReadInteger: Integer;
begin
  try
    Result := inherited ReadInteger();
  except
    on E: Exception do
      Quit(_FAIL, E.Message);
  end;
end;

function TAnswerStream.ReadLongInt: Integer;
begin
  try
    Result := inherited ReadLongInt();
  except
    on E: Exception do
      Quit(_FAIL, E.Message);
  end;
end;

function TAnswerStream.ReadBigInteger: Int64;
begin
  try
    Result := inherited ReadBigInteger();
  except
    on E: Exception do
      Quit(_FAIL, E.Message);
  end;
end;

function TAnswerStream.ReadReal: Extended;
begin
  try
    Result := inherited ReadReal();
  except
    on E: Exception do
      Quit(_FAIL, E.Message);
  end;
end;

function TAnswerStream.ReadRealFixed(DigitsAfterDot: Integer): Extended;
begin
  try
    Result := inherited ReadRealFixed(DigitsAfterDot);
  except
    on E: Exception do
      Quit(_FAIL, E.Message);
  end;
end;

function TAnswerStream.ReadString: string;
begin
  try
    Result := inherited ReadString();
  except
    on E: Exception do
      Quit(_FAIL, E.Message);
  end;
end;

function TAnswerStream.ReadWord(Before, After: TCharset): string;
begin
  try
    Result := inherited ReadWord(Before, After);
  except
    on E: Exception do
      Quit(_FAIL, E.Message);
  end;
end;

{ TOutputStream }

constructor TOutputStream.Create;
begin
  try
    inherited;
    fHandle := GetStdHandle(STD_OUTPUT_HANDLE);
    if fHandle = INVALID_HANDLE_VALUE then
      raise Exception.CreateFmt('GetStdHandle function failed: %s', [SysErrorMessage(GetLastError())]);
    FillBuffer();
  except
    on E: Exception do
      raise Exception.CreateFmt('Output stream error on creating: %s', [E.Message]);
  end;
end;

destructor TOutputStream.Destroy;
begin

  inherited;
end;

function TOutputStream.ReadInteger: Integer;
begin
  try
    Result := inherited ReadInteger();
  except
    on E: Exception do
      Quit(_PE, E.Message);
  end;
end;

function TOutputStream.ReadLongInt: Integer;
begin
  try
    Result := inherited ReadLongInt();
  except
    on E: Exception do
      Quit(_PE, E.Message);
  end;
end;

function TOutputStream.ReadBigInteger: Int64;
begin
  try
    Result := inherited ReadBigInteger();
  except
    on E: Exception do
      Quit(_FAIL, E.Message);
  end;
end;

function TOutputStream.ReadReal: Extended;
begin
  try
    Result := inherited ReadReal();
  except
    on E: Exception do
      Quit(_PE, E.Message);
  end;
end;

function TOutputStream.ReadRealFixed(DigitsAfterDot: Integer): Extended;
begin
  try
    Result := inherited ReadRealFixed(DigitsAfterDot);
  except
    on E: Exception do
      Quit(_PE, E.Message);
  end;
end;

function TOutputStream.ReadString: string;
begin
  try
    Result := inherited ReadString();
  except
    on E: Exception do
      Quit(_PE, E.Message);
  end;
end;

function TOutputStream.ReadWord(Before, After: TCharset): string;
begin
  try
    Result := inherited ReadWord(Before, After);
  except
    on E: Exception do
      Quit(_PE, E.Message);
  end;
end;

initialization
  DecimalSeparator := '.';
  
  try
    inf := TInputStream.Create;
    ouf := TOutputStream.Create;
    ans := TAnswerStream.Create;
  except
    on E: Exception do
      Quit(_FAIL, E.Message);    
  end;

end.
 
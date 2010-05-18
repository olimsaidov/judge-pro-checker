unit OptionsUnit;

interface

uses
  SysUtils, IniFiles, CommonTypesUnit;

type
  TOptions = class(TObject)
  private
    fIniFile: TIniFile;
    fCheckInterval: Cardinal;
    fProblemsRootDirectory: string;
    fWorkDirectory: string;
    fRestrictedUserName: string;
    fRestrictedUserPassword: string;

    function GetOptionGetter(const Section: String; const Ident: String): Variant;
  public
    constructor Create;
    destructor Destroy; override;
    function SectionExists(const Section: String): boolean;

    property GetOption[const Section: String; const Ident: String]: Variant read GetOptionGetter; default;
    property CheckInterval: Cardinal read fCheckInterval; //for perfomance reasons
    property ProblemsRootDirectory: string read fProblemsRootDirectory;
    property WorkDirectory: string read fWorkDirectory;
    property RestrictedUserName: string read fRestrictedUserName;
    property RestrictedUserPassword: string read fRestrictedUserPassword;
  end;

var
  Options: TOptions;

implementation

{ TOptions }

constructor TOptions.Create;
var
  FileName: string;
begin
  FileName := ExtractFilePath(ParamStr(0)) + OPTIONS_FILE_NAME;
  if not FileExists(FileName) then
    raise Exception.CreateFmt('Unable to open options file "%s". The file does not exits.', [FileName]);
  fIniFile := TIniFile.Create(FileName);

  fCheckInterval := Self['Main', 'CheckInterval'];
  fProblemsRootDirectory := IncludeTrailingPathDelimiter(Self['Main', 'ProblemsRootDirectory']);
  fWorkDirectory := IncludeTrailingPathDelimiter(Self['Main', 'WorkDirectory']);
  fRestrictedUserName := Self['Main', 'RestrictedUserName'];
  fRestrictedUserPassword := Self['Main', 'RestrictedUserPassword'];
end;



destructor TOptions.Destroy;
begin
  fIniFile.Free();
  inherited;
end;

function TOptions.GetOptionGetter(const Section: String; const Ident: String): Variant;
begin
  if not fIniFile.SectionExists(Section) then
    raise Exception.CreateFmt('Section %s does not exists in configuration file', [Section]);
  if not fIniFile.ValueExists(Section, Ident) then
    raise Exception.CreateFmt('Identificator %s does not exists in configuration file', [Ident]);

  if fIniFile.ValueExists(Section, Ident) then
    result := fIniFile.ReadString(Section, Ident, '0');
end;

function TOptions.SectionExists(const Section: String): boolean;
begin
  Result := fIniFile.SectionExists(Section);
end;

end.

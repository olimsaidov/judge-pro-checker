program JudgePro;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  MainUnit in 'MainUnit.pas',
  OptionsUnit in 'OptionsUnit.pas',
  ProblemParamsUnit in 'ProblemParamsUnit.pas',
  CompilerUnit in 'CompilerUnit.pas',
  SubmitUnit in 'SubmitUnit.pas',
  SandBoxUnit in 'SandBoxUnit.pas',
  DataBaseUnit in 'DataBaseUnit.pas',
  CheckerUnit in 'CheckerUnit.pas',
  Windows,
  CommonTypesUnit in 'CommonTypesUnit.pas',
  ActiveSubmitsIdListUnit in 'ActiveSubmitsIdListUnit.pas',
  ThreadsListUnit in 'ThreadsListUnit.pas';
begin
  Writeln(#13#10' Automated judge checking system.'#13#10' Created by Olim Saidov. (c) 2009'#13#10' If you find any any bugs report to olim.mail@gmail.com'#13#10);
  try
    Options := TOptions.Create;
    DataBase := TDataBase.Create;
    ProblemParamsCache := TProblemParamsCache.Create;
    CompilerCollection := TCompilerCollection.Create;
    ActiveSubmitsIdList := TActiveSubmitsIdList.Create;
    ThreadsList := TThreadsList.Create;
    Main := TMainClass.Create;
    Main.Execute
  except
    on E:Exception do
      MessageBox(0, PChar(Format('Fatal error occured: %s'#13#10#13#10'Application will be terminated.', [E.Message])), 'Application Error', $10);
  end;
end.

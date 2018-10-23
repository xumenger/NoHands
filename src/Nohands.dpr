program Nohands;

uses
  Forms,
  MainForm in 'MainForm.pas' {TestForm},
  U_AutoTest in 'U_AutoTest.pas',
  U_BaseDefine in 'U_BaseDefine.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TTestForm, TestForm);
  Application.Run;
end.

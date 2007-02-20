program WormNATConfig;

uses
  Forms,
  Main in 'Main.pas' {MainForm},
  Threads in 'Threads.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.

unit Threads;

interface

uses
  Classes;

type
  TWorker = class(TThread)
  private
  protected
    procedure Execute; override;
  end;

var
  Job: Integer;
  Done: Boolean;
  CheckResult: Boolean;
  FindResult: PChar;

implementation
uses
  Windows, Main;

function FindProxy : PChar; stdcall; external 'SocksFinder.dll';
function CheckProxy(Target: PChar): Boolean; stdcall; external 'SocksFinder.dll';

procedure TWorker.Execute;
begin
  Done:=False;
  case Job of
    1: CheckResult:=CheckProxy(PChar(MainForm.SOCKSServer.Text+':'+MainForm.SOCKSPort.Text));
    2: FindResult:=FindProxy;
  end;
  Done:=True;
  FreeOnTerminate:=True;
end;

end.

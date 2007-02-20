{$APPTYPE CONSOLE}

uses
  SysUtils;

function FindProxy : PChar; stdcall; external 'SocksFinder.dll';
function CheckProxy(Target: PChar): Boolean; stdcall; external 'SocksFinder.dll';

begin
  WriteLn(FindProxy);
end.

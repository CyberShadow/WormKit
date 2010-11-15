library wkCrashOnExit;

{$IMAGEBASE $62800000}

uses Windows, USysUtils, madCHook;

// ***************************************************************

var
  ExitProcessNext: procedure(uExitCode: UINT); stdcall;

// ***************************************************************

procedure ExitProcessCallback(uExitCode: UINT); stdcall;
begin
  asm int 3 end;
end;

// ***************************************************************

begin
  HookAPI('kernel32.dll', 'ExitProcess', @ExitProcessCallback, @ExitProcessNext);
end.

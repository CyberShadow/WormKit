library wkAntiKeyboardHook;

{$IMAGEBASE $61800000}

uses Windows, madCodeHook;

var 
  SetWindowsHookExANext : function(idHook: Integer; lpfn: TFNHookProc; hmod: HINST; dwThreadId: DWORD): HHOOK; stdcall;

// ***************************************************************

function SetWindowsHookExACallback(idHook: Integer; lpfn: TFNHookProc; hmod: HINST; dwThreadId: DWORD): HHOOK; stdcall;
begin
  if idHook=13 then   // WH_KEYBOARD_LL
    begin
    Result:=0;
    SetLastError(ERROR_ACCESS_DENIED);
    end
  else
    Result:=SetWindowsHookExANext(idHook, lpFn, hmod, dwThreadId);
end;

// ***************************************************************

begin
  HookAPI('user32.dll',    'SetWindowsHookExA',   @SetWindowsHookExACallback,   @SetWindowsHookExANext);
end.

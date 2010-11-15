{$APPTYPE CONSOLE}

library wkForceFrontendResolution;

uses
  Windows, madCHook;

var
  Next: Pointer;

procedure Callback; assembler;
asm
  mov     ecx, 1024
  mov     edx, 768
  
  push    ebp
  mov     ebp, esp
  sub     esp, 494h
  mov     eax, $44F189
  jmp     eax
end;

procedure Patch(Addr: Cardinal; Value: Byte);
var
  OldProtect: Cardinal;
begin
  VirtualProtect(Pointer(Addr), 1, PAGE_EXECUTE_READWRITE, OldProtect);
  PByte(Addr)^ := Value;
end;

// ***************************************************************

var
  ShowWindowNext: function(hWnd: HWND; nCmdShow: Integer): BOOL; stdcall;

// ***************************************************************

function ShowWindowCallback(hWnd: HWND; nCmdShow: Integer): BOOL; stdcall;
begin
  if nCmdShow=SW_HIDE then
  begin
    SetWindowPos(hWnd, 0, 0, 0, 0, 0, SWP_HIDEWINDOW or SWP_NOACTIVATE or SWP_NOMOVE or SWP_NOOWNERZORDER or SWP_NOSENDCHANGING or SWP_NOSIZE or SWP_NOZORDER);
    Result := true; // hack
  end
  else
    Result := ShowWindowNext(hWnd, nCmdShow);
end;

// ***************************************************************


begin
  HookCode(Pointer($44F180), @Callback, Next);
  HookAPI('user32.dll', 'ShowWindow', @ShowWindowCallback, @ShowWindowNext);
  
  Patch($44F1A8, $90);
  Patch($44F1A9, $90);
  Patch($44F1AA, $90);
  Patch($44F1AB, $90);
  Patch($44F1AC, $90);
end.
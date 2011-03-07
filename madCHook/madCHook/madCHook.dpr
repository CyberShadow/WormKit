// Drop-in simple madCHook replacement.

library madCHook;

uses
  Windows;

function CreateProcessExA(lpApplicationName: PChar; lpCommandLine: PChar;
  lpProcessAttributes, lpThreadAttributes: PSecurityAttributes;
  bInheritHandles: BOOL; dwCreationFlags: DWORD; lpEnvironment: Pointer;
  lpCurrentDirectory: PChar; const lpStartupInfo: TStartupInfo;
  var lpProcessInformation: TProcessInformation; lpDllName: PChar): BOOL; 
  stdcall;
var
  lpDllNameRemote: Pointer;
  dwWritten, dwThreadID: Cardinal;
  hThread: THandle;
begin
  Result := CreateProcess(lpApplicationName, lpCommandLine, lpProcessAttributes, 
    lpThreadAttributes, bInheritHandles, dwCreationFlags or CREATE_SUSPENDED, 
    lpEnvironment, lpCurrentDirectory, lpStartupInfo, lpProcessInformation);
  if not Result then Exit;
  Result := False;
  lpDllNameRemote := VirtualAllocEx(lpProcessInformation.hProcess, nil, Length(lpDllName)+1, MEM_COMMIT, PAGE_READWRITE);
  if lpDllNameRemote=nil then Exit;
  WriteProcessMemory(lpProcessInformation.hProcess, lpDllNameRemote, lpDllName, Length(lpDllName)+1, dwWritten);
  hThread := CreateRemoteThread(lpProcessInformation.hProcess, nil, 0, GetProcAddress(GetModuleHandle('kernel32.dll'), 'LoadLibraryA'), lpDllNameRemote, 0, dwThreadID);
  WaitForSingleObject(hThread, INFINITE);
  ResumeThread(lpProcessInformation.hThread);
  Result := True;
end;

type
  THookJump = packed record
    Jump: Byte;
    Offset: Cardinal;
  end;
  PHookJump = ^THookJump;

  THook = class
    constructor Create(P, FN: Pointer);
    procedure Hook;
    procedure Unhook;
  private  
    Target: PHookJump;
    OldCode, NewCode: THookJump;
  end;

procedure MakeWritable(Address: Pointer; Size: Cardinal);
var
  Old: Cardinal;
begin
  VirtualProtect(Address, Size, PAGE_EXECUTE_WRITECOPY, Old);
end;

constructor THook.Create(P, FN: Pointer);
begin
  Target := PHookJump(P);
  OldCode := Target^;
  NewCode.Jump := $E9; // long jump
  NewCode.Offset := Cardinal(FN) - (Cardinal(Target)+5);
  MakeWritable(P, 5);
  Hook;
end;

procedure THook.Hook;
begin
  Target^ := NewCode;
end;

procedure THook.Unhook;
begin
  Target^ := OldCode;
end;

function HookCode(Address, Callback: Pointer; var Next: Pointer): Boolean; stdcall;
begin
  Result := False;
end;

function HookAPI(lpDllName, lpFunctionName: PChar; Callback: Pointer; var Next: Pointer): Boolean; stdcall;
begin
  Result := False;
end;

procedure AutoUnhook(Module: THandle); stdcall; 
begin
end;

exports
  CreateProcessExA, HookCode, HookAPI, AutoUnhook;

end.
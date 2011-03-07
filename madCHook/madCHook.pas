unit madCHook; // simple interface to madCHook replacement

interface

uses
  Windows;

function CreateProcessEx(lpApplicationName: PChar; lpCommandLine: PChar; lpProcessAttributes, lpThreadAttributes: PSecurityAttributes; bInheritHandles: BOOL; dwCreationFlags: DWORD; lpEnvironment: Pointer; lpCurrentDirectory: PChar; const lpStartupInfo: TStartupInfo; var lpProcessInformation: TProcessInformation; lpDllName: PChar): BOOL; stdcall; external 'madCHook.dll';
function HookCode(Address, Callback: Pointer; var Next: Pointer): Boolean; stdcall; external 'madCHook.dll';
function HookAPI(lpDllName, lpFunctionName: PChar; Callback: Pointer; var Next: Pointer): Boolean; stdcall; external 'madCHook.dll';

implementation

end.
library ReplayShark;

// This source code is for demonstrational purposes only, and is not meant to be recompiled.
// I will not respond to requests of providing the source code or binaries of missing units.

// This code is (c) G-Lite, with many thanks to The_CyberShadow.
// Redistribution outside the initial package, modification, compilation,
// use for the means of reverse engineering of the binary is prohibited.

uses
  USysUtils,
  Windows,
  Messages,
  mmSystem,
  madCHook;

// Globals

var
  // The Worms game window.
  WormsWindow: HWND;
  // The replay file's handle.
  CurrentReplay: THandle;
  // The replay file's name.
  CurrentReplayName: AnsiString;
  // Frames at which the snapshot hotkey was pressed.
  SnappedFrames: array[1..5] of Integer;


// Helpers

function Max(A, B: Integer): Integer;
begin
  if A>B then Max:=A else Max:=B;
end;

procedure ClearReplay;
var
  i: Integer;
begin
    CurrentReplay := INVALID_HANDLE_VALUE;
    CurrentReplayName := '';
    for i := 1 to 5 do
        SnappedFrames[i] := 0
end;

procedure FlushReplay;
var
  NewFileName: AnsiString;
  i, SnapCount, GameTime, Minutes, Seconds: Integer;
begin
    NewFileName := ExtractFileName (CurrentReplayName);
    SetLength (NewFileName, Length (NewFileName) - 7);
    SnapCount := 0;
    for i := 1 to 5 do
    begin
        if SnappedFrames[i] = 0 then
            Break;

        // This basically subtracts 10 seconds and then rounds it
        // off downward to the nearest 5 seconds
        GameTime := Max((SnappedFrames[i] div 250) - 2, 0);
        Minutes := GameTime div 12;
        Seconds := (GameTime mod 12) * 5;
        NewFileName := NewFileName + ' [' + IntToStrLen (Minutes, 2) + '.' + IntToStrLen (Seconds, 2) + ']';

        Inc (SnapCount)
    end;
    if SnapCount < 1 then   // No snapshots
        Exit;
    NewFileName := 'User\ReplayShark\' + NewFileName + '.WAgame';

    if ForceDirectories ('User\ReplayShark') = false then
        Exit;

    CopyFileA (PAnsiChar (CurrentReplayName), PAnsiChar (NewFileName), true)
end;


// Subclass

var
  WormsSubclassNext: TFNWndProc;

function WormsSubclass (
    hwnd: HWND;
    uMsg: UINT;
    wParam: WPARAM;
    lParam: LPARAM
): LRESULT; stdcall;
var
  WormsGame: PGame;
  i: Integer;
begin
    if (uMsg = WM_KEYDOWN) and (wParam = VK_F12) and (HI (GetKeyState (VK_CONTROL)) > 0) then
    begin
        Result := 0;

        if (lParam and (1 shl 30)) > 0 then
            Exit;

        if CurrentReplay = INVALID_HANDLE_VALUE then
            Exit;

        WormsGame := GetGame;
        if WormsGame = nil then
            Exit;

        for i := 1 to 5 do
        begin
            if SnappedFrames[i] = 0 then
            begin
                SnappedFrames[i] := WormsGame^.FrameNr;    
                // This method of playing a sound doesn't respect W:A's volume setting
                sndPlaySound ('DATA\Wav\SharkSnap.wav', SND_ASYNC or SND_NODEFAULT);
                Exit
            end
        end
    end
    else
        Result := CallWindowProc (WormsSubclassNext, hwnd, uMsg, wParam, lParam)
end;


// API Hooks

var CreateWindowExANext: function (
    dwExStyle: DWORD;
    lpClassName, lpWindowName: PAnsiChar;
    dwStyle: DWORD;
    x, y, nWidth, nHeight: Integer;
    hWndParent: HWND;
    hMenu: HMENU;
    hInstance: HINST;
    lpParam: Pointer
): HWND; stdcall;

function CreateWindowExAHook (
    dwExStyle: DWORD;
    lpClassName, lpWindowName: PAnsiChar;
    dwStyle: DWORD;
    x, y, nWidth, nHeight: Integer;
    hWndParent: HWND;
    hMenu: HMENU;
    hInstance: HINST;
    lpParam: Pointer
): HWND; stdcall;
begin
    Result := CreateWindowExANext (dwExStyle, lpClassName, lpWindowName, dwStyle, x, y, nWidth, nHeight, hWndParent, hMenu, hInstance, lpParam);
    if (Result <> 0) and (WormsWindow = 0) and (lpClassName = 'Worms2D') and (lpWindowName = 'Worms2D') then
    begin
        WormsWindow := Result;
        WormsSubclassNext := TFNWndProc (SetWindowLong (WormsWindow, GWL_WNDPROC, Integer (@WormsSubclass)))
    end
end;


var
  DestroyWindowNext: function (
    hWnd: HWND
  ): BOOL; stdcall;

function DestroyWindowHook (
  hWnd: HWND
): BOOL; stdcall;
begin
    Result := DestroyWindowNext (hWnd);
    if Result and (hWnd = WormsWindow) then
        WormsWindow := 0
end;


var
  CreateFileANext: function (
    lpFileName: PAnsiChar;
    dwDesiredAccess, dwShareMode: DWORD;
    lpSecurityAttributes: PSecurityAttributes;
    dwCreationDisposition, dwFlagsAndAttributes: DWORD;
    hTemplateFile: THandle
  ): THandle; stdcall;

function CreateFileAHook (
  lpFileName: PAnsiChar;
  dwDesiredAccess, dwShareMode: DWORD;
  lpSecurityAttributes: PSecurityAttributes;
  dwCreationDisposition, dwFlagsAndAttributes: DWORD;
  hTemplateFile: THandle
): THandle; stdcall;
begin
    Result := CreateFileANext (lpFileName, dwDesiredAccess, dwShareMode, lpSecurityAttributes, dwCreationDisposition, dwFlagsAndAttributes, hTemplateFile);
    if (CurrentReplay = INVALID_HANDLE_VALUE) and (Result <> INVALID_HANDLE_VALUE) and (Copy(lpFileName, Length(lpFileName)-6, 7)='.WAgame') then
    begin
        CurrentReplay := Result;
        CurrentReplayName := lpFileName
    end
end;


var
  CloseHandleNext: function (
    hObject: THandle
  ): BOOL; stdcall;

function CloseHandleHook (
  hObject: THandle
): BOOL; stdcall;
begin
    Result := CloseHandleNext (hObject);
    if Result and (CurrentReplay <> INVALID_HANDLE_VALUE) and (hObject = CurrentReplay) then
    begin
        // A really funky stack overflow happens if this is not done before CopyFile.
        CurrentReplay := INVALID_HANDLE_VALUE;

        FlushReplay;
        ClearReplay
    end
end;


// Library entrypoint

begin
    WormsWindow := 0;
    ClearReplay;

    CollectHooks;
    HookAPI('user32.dll', 'CreateWindowExA', @CreateWindowExAHook, @CreateWindowExANext);
    HookAPI('user32.dll', 'DestroyWindow', @DestroyWindowHook, @DestroyWindowNext);
    HookAPI('kernel32.dll', 'CreateFileA', @CreateFileAHook, @CreateFileANext);
    HookAPI('kernel32.dll', 'CloseHandle', @CloseHandleHook, @CloseHandleNext);
    FlushHooks
end.

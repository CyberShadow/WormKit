library wkColorFix;

uses
  Windows, TlHelp32, Messages;

function OpenThread(dwDesiredAccess: DWORD; bInheritHandle: BOOL; dwThreadId: DWORD): THandle; stdcall; external 'kernel32.dll';
const THREAD_SUSPEND_RESUME = $0002;

function PauseResumeExplorer(bResumeThread: Boolean): Boolean;
var
  hSnapshot, hThread: THandle;
  pe32: TProcessEntry32;
  te32: TThreadEntry32;
  dwExplorerPID: DWORD;
begin
  Result := False;

  hSnapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  pe32.dwSize := SizeOf(TProcessEntry32);
  dwExplorerPID := 0;
  if Process32First(hSnapshot, pe32) then
    repeat
      if lstrcmpi(pe32.szExeFile, 'explorer.exe')=0 then
      begin
        dwExplorerPID := pe32.th32ProcessID;
        break;
      end;
    until not Process32Next(hSnapshot, pe32);
  CloseHandle (hSnapshot);
  if dwExplorerPID=0 then
    Exit;

  hSnapshot := CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0); 
  if hSnapshot=INVALID_HANDLE_VALUE then
    Exit;

  te32.dwSize := SizeOf(TThreadEntry32); 

  if Thread32First(hSnapshot, te32) then
  begin
    repeat
      if te32.th32OwnerProcessID = dwExplorerPID then
      begin
        hThread := OpenThread(THREAD_SUSPEND_RESUME, False, te32.th32ThreadID);
        if bResumeThread then
          ResumeThread(hThread)
        else
          SuspendThread(hThread);
        CloseHandle(hThread);
      end;
    until not Thread32Next(hSnapshot, te32);
    Result := True; 
  end;

  CloseHandle (hSnapshot); 
end;

function IsWAActive: Boolean;
var
  H: HWND;
  PID: DWORD;
  R: TRect;
begin
  Result := False;
  H := GetForegroundWindow;
  GetWindowThreadProcessId(h, PID);
  if PID <> GetCurrentProcessId then
    Exit;
  GetWindowRect(H, R);
  if (R.Top<>0) or (R.Left<>0) then
    Exit;
  Result := True;
end;

var
  WAActive, LastWAActive: Boolean;

procedure ThreadProc(Nothing: Pointer); stdcall;
begin
  LastWAActive := False;
  repeat
    WAActive := IsWAActive;
    if WAActive<>LastWAActive then
    begin
      if PauseResumeExplorer(not WAActive) then
        LastWAActive := WAActive
      else
      begin
        MessageBeep(MB_ICONERROR);
        Sleep(1000);
      end;
    end;
    Sleep(1);
  until False;
end;

procedure Stop; 
begin
  if LastWAActive then
  begin
    PauseResumeExplorer(True);
    LastWAActive := False;
  end;
  //MessageBeep(0);
end;

procedure DllMain(Reason: Integer);
begin
  if Reason=DLL_PROCESS_DETACH then
    Stop;
end;

var
  ThreadID: DWORD;

begin
  CreateThread(nil, 0, @ThreadProc, nil, 0, ThreadID);
  DllProc := @DllMain;
end.
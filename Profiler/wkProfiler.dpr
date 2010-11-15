{$IMAGEBASE $62800000}

library wkProfiler;

uses
  Windows, USysUtils;

function MiniDumpWriteDump(hProcess: THandle; ProcessId: DWORD; hFile: THandle; DumpType: Integer; ExceptionParam: Pointer; UserStreamParam: Pointer; CallbackParam: Pointer): BOOL; stdcall; external 'dbghelp.dll' name 'MiniDumpWriteDump';

type
  TPage = array[0..$FFFF] of Cardinal;
  PPage = ^TPage;

var
  Pages: array[0..$FFFF] of PPage;

// ***************************************************************

procedure SaveMinidump;
var
  hMiniDumpFile: THandle;
begin
  // Create the file
  hMiniDumpFile := CreateFile(
    'PROFILE.DMP',
    GENERIC_WRITE,
    0,
    nil,
    CREATE_ALWAYS,
    FILE_ATTRIBUTE_NORMAL or FILE_FLAG_WRITE_THROUGH,
    0);

  // Write the minidump to the file
  if hMiniDumpFile <> INVALID_HANDLE_VALUE then
  begin
    MiniDumpWriteDump(GetCurrentProcess, GetCurrentProcessId, hMiniDumpFile, 0, nil, nil, nil);

    // Close file
    CloseHandle(hMiniDumpFile);
  end;
end;


procedure ProfilerThreadProc(MainThread: THandle); stdcall;
var
  StartTicks: Cardinal;
  Seg, Off: Word;
  Context: TContext;
  F: Text;
begin
  while GetKeyState(VK_CANCEL)>=0 do Sleep(1);
  
  StartTicks := GetTickCount;
  while GetTickCount-StartTicks<10*1000 do
  begin
    FillChar(Context, SizeOf(Context), 0);
    Context.ContextFlags := CONTEXT_CONTROL;
    SuspendThread(MainThread);
    if not GetThreadContext(MainThread, Context) then Break;
    ResumeThread(MainThread);
    Seg := Context.Eip shr 16;
    Off := Context.Eip and $FFFF;
    if Pages[Seg]=nil then
    begin
      New(Pages[Seg]);
      FillChar(Pages[Seg]^, SizeOf(Pages[Seg]^), 0);
    end;
    Inc(Pages[Seg]^[Off]);
    Sleep(0);
  end;

  Assign(F, 'profile.log');
  ReWrite(F);
  for Seg:=0 to $FFFF do
    if Pages[Seg]<>nil then
      for Off:=0 to $FFFF do
        if Pages[Seg]^[Off]<>0 then
          WriteLn(F, IntToHex(Seg, 4), IntToHex(Off, 4), ': ', Pages[Seg]^[Off]:10);
  Close(F);

  SaveMinidump;

  TerminateProcess(GetCurrentProcess, 12345);
end;

function StartProfiler: Boolean;
var
  MyThread: THandle;
  ThreadId: DWORD;
  DwordResult: DWORD absolute Result;
begin
  Result := False;
  if not DuplicateHandle(GetCurrentProcess, GetCurrentThread, GetCurrentProcess, @MyThread, 0, false, DUPLICATE_SAME_ACCESS) then
    Exit;
  if CreateThread(nil, 0, @ProfilerThreadProc, Pointer(MyThread), 0, ThreadId) = 0 then
    Exit;
  Result := True;
end;

begin
  if not StartProfiler then
    MessageBox(0, 'The profiler couldn''t be started due to an error.', 'wkProfiler', MB_ICONERROR);
end.
{$IMAGEBASE $62800000}

library wkLogFreezes;

uses
  Types, Windows, USysUtils, madCHook;

function MiniDumpWriteDump(hProcess: THandle; ProcessId: DWORD; hFile: THandle; DumpType: Integer; ExceptionParam: Pointer; UserStreamParam: Pointer; CallbackParam: Pointer): BOOL; stdcall; external 'dbghelp.dll' name 'MiniDumpWriteDump';

procedure SaveMinidump;
var
  hMiniDumpFile: THandle;
begin
  // Create the file
  hMiniDumpFile := CreateFile(
    'FREEZELOG.DMP',
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

// ***************************************************************

procedure Log(S: String);
var
  F: Text;
begin
  Assign(F, 'freeze.log');
  {$I-}
  Append(F);
  if IOResult<>0 then ReWrite(F);
  {$I+}
  if IOResult<>0 then Exit;
  WriteLn(F, '[', {TimeToStr(Now)}TimeStr, '] ', {ParamStr(0), ' ', GetTickCount, ' ', }S);
  Close(F);
end;

function ReadDword(Segm, Offs: Cardinal): Cardinal; assembler;
asm
  push gs
  mov gs, Segm
  mov eax, Offs
  mov eax, dword ptr gs:eax
  pop gs
end;

function MySS: Cardinal; assembler;
asm
  mov eax, ss
end;

const
  MaxCallStackSize = 64;

type
  TCallStack = record
    Addresses: array[0..MaxCallStackSize-1] of Cardinal;
    Count: Cardinal;
  end;

procedure GetCallStack(const Context: TContext; var CallStack: TCallStack);
var
  P, V, N, Bottom: Cardinal;
begin
  CallStack.Count := 1;
  CallStack.Addresses[0] := Context.Eip;
  P := Context.Ebp;
  
  //Bottom := ReadDword(Context.SegFs, 4);
  Bottom := $400000;

  //Log('Bottom: ' + IntToHex(Bottom, 8));
  //Log('Thread SS: ' + IntToHex(Context.SegSs, 8));
  //Log('My SS: ' + IntToHex(MySS, 8));
  try
    while P<>0 do
    begin
      //Log(IntToHex(P, 8) + ' ...');
      V := ReadDword(Context.SegSs, P+4);
      if V<>0 then
      begin
        CallStack.Addresses[CallStack.Count] := V;
        Inc(CallStack.Count);
        if CallStack.Count=MaxCallStackSize then
          Break;
      end;
      N := ReadDword(Context.SegSs, P);
      //Log(IntToHex(P, 8) + ' => ' + IntToHex(V, 8) + ' / ' + IntToHex(N, 8));
      if (N <= P) or (N > Bottom) then
        break;
      P := N;
    end;
  except
    end;{}
  //Log('======================');
end;

function CallStackToString(var C: TCallStack): String;
var
  I: Cardinal;
begin
  Result := '';
  for I:=0 to C.Count-1 do
  begin
    Result := Result + IntToHex(C.Addresses[I], 8);
    if I < C.Count-1 then
      Result := Result + ' <= ';
  end;
end;

function StacksEqual(const C1, C2: TCallStack): Boolean;
var
  I: Integer;
begin
  Result := False;
  if C1.Count<>C2.Count then
    Exit;
  for I:=0 to C1.Count-1 do
    if C1.Addresses[I]<>C2.Addresses[I] then
      Exit;
  Result := True;
end;

const
  Threshold = 100;

procedure ProfilerThreadProc(MainThread: THandle); stdcall;
var
  Time, LastTime, NewIPTime: Cardinal;
  Stack, LastStack: TCallStack;
  Context: TContext;
begin
  LastTime := GetTickCount;
  LastStack.Count := 0;
  NewIPTime := LastTime;
  try
  repeat
    //Log('Sleeping...');
    Sleep(1);

    //Log('Time check...');
    Time := GetTickCount;
    if (Time-LastTime>Threshold) or (Time<LastTime) then
      Log('Time jumped by ' + IntToStr(Time-LastTime) + 'ms');
    LastTime := Time;
    
    //Log('Getting data...');
    FillChar(Context, SizeOf(Context), 0);
    Context.ContextFlags := CONTEXT_CONTROL or CONTEXT_SEGMENTS;
    SuspendThread(MainThread);
    if not GetThreadContext(MainThread, Context) then Break;
    //Log('Getting call stack...');
    //try
      GetCallStack(Context, Stack);
    //except
    //  Log('ERROR ERROR');
    //end;
    //Log('Resuming...');
    ResumeThread(MainThread);

    //Log('Check...');
    if not StacksEqual(Stack, LastStack) then
    begin
      if Time-NewIPTime>Threshold then
        Log('W:A spent ' + IntToStr(Time-NewIPTime) + 'ms at ' + CallStackToString(LastStack));
      LastStack := Stack;
      NewIPTime := Time;
    end;
    
  until GetKeyState(VK_CANCEL)<0;
  except Log('ERROR ERROR'); end;
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

var
  ExitProcessNext: procedure(uExitCode: UINT); stdcall;

procedure ExitProcessCallback(uExitCode: UINT); stdcall;
begin
  //asm int 3 end;
  SaveMinidump;
  ExitProcessNext(uExitCode);
end;

begin
  if not StartProfiler then
    MessageBox(0, 'The profiler couldn''t be started due to an error.', 'wkProfiler', MB_ICONERROR);
  HookAPI('kernel32.dll', 'ExitProcess', @ExitProcessCallback, @ExitProcessNext);
end.

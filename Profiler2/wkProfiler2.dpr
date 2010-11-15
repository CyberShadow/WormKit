{$IMAGEBASE $62800000}

library wkProfiler;

uses
  Windows, SysUtils;

function MiniDumpWriteDump(hProcess: THandle; ProcessId: DWORD; hFile: THandle; DumpType: Integer; ExceptionParam: Pointer; UserStreamParam: Pointer; CallbackParam: Pointer): BOOL; stdcall; external 'dbghelp.dll' name 'MiniDumpWriteDump';

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

// ***************************************************************

(*
procedure Log(S: String);
var
  F: Text;
begin
  Assign(F, 'profiler.log');
  {$I-}
  Append(F);
  if IOResult<>0 then ReWrite(F);
  {$I+}
  if IOResult<>0 then Exit;
  WriteLn(F, '[', TimeStr, '] ', {ParamStr(0), ' ', GetTickCount, ' ', }S);
  Close(F);
end;
*)

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

function GetStackBottom: Cardinal; assembler;
asm
  mov eax, fs:4
end;

const
  MaxCallStackSize = 64;

type
  TCallStack = record
    Addresses: array[0..MaxCallStackSize-1] of Cardinal;
    Count, Hits: Cardinal;
  end;

var
  StackBottom: Cardinal;

procedure GetCallStack(const Context: TContext; var CallStack: TCallStack);
var
  P, V, N, I: Cardinal;
  Addresses: array[0..MaxCallStackSize-1] of Cardinal;
  Count: Cardinal;
begin
  FillChar(CallStack, SizeOf(CallStack), 0);
  Count := 1;
  Addresses[0] := Context.Eip;
  N := Context.Ebp;
  P := 0;
  
  //StackBottom := $400000;

  //Log('StackBottom: ' + IntToHex(StackBottom, 8));
  //Log('Thread SS: ' + IntToHex(Context.SegSs, 8));
  //Log('My SS: ' + IntToHex(MySS, 8));
  try
    while (P < N) and (N < StackBottom) do
    begin
      P := N;
      //Log(IntToHex(P, 8) + ' ...');
      if IsBadReadPtr(Pointer(P), 8) then
        Break;
      V := ReadDword(Context.SegSs, P+4);
      if V<>0 then
      begin
        Addresses[Count] := V;
        Inc(Count);
        if Count=MaxCallStackSize then
          Break;
      end;
      N := ReadDword(Context.SegSs, P);
      //Log(IntToHex(P, 8) + ' => ' + IntToHex(V, 8) + ' / ' + IntToHex(N, 8));
    end;
  except
    end;{}
  CallStack.Count := Count;
  CallStack.Hits := 0;
  for I:=0 to Count-1 do
    CallStack.Addresses[I] := Addresses[Count-I-1];
  //Log('======================');
end;

// ***************************************************************

type
  PNode = ^TNode;
  TNode = record
    Children: array[Boolean] of PNode;
    Count: Cardinal;
  end;

var
  RootNode: TNode;

procedure AddCallstack(const CallStack: TCallStack);
var
  Node: PNode;
  I, Mask: Cardinal;
  B: Boolean;
begin
  Node := @RootNode;
  I := 0;
  while I<CallStack.Count do
  begin
    Mask := $80000000;
    repeat
      B := (CallStack.Addresses[I] and Mask)<>0;
      if Node.Children[B]=nil then
      begin
        New(Node.Children[B]);
        Node := Node.Children[B];
        Node.Children[False] := nil;
        Node.Children[True] := nil;
        Node.Count := 0;
      end
      else
        Node := Node.Children[B];
      Mask := Mask shr 1;
    until Mask=0;
    Inc(I);
  end;
  Inc(Node.Count);
end;

var
  CurrentStack: array[0..MaxCallStackSize-1] of Cardinal;
  F: Text;

procedure DumpTree(Node: PNode; I: Integer; Mask: Cardinal);
var
  J: Integer;
begin
  if Node.Count>0 then
  begin
    Write(F, Node.Count:10, ': ');
    for J:=0 to I do
      Write(F, IntToHex(CurrentStack[J], 8), ' ');
    WriteLn(F);
  end;
  Mask := Mask shr 1;
  if Mask=0 then
  begin
    Mask := $80000000;
    Inc(I);
  end;
  if Node.Children[False]<>nil then
  begin
    CurrentStack[I] := CurrentStack[I] and not Mask;
    DumpTree(Node.Children[False], I, Mask);
  end;
  if Node.Children[True]<>nil then
  begin
    CurrentStack[I] := CurrentStack[I] or Mask;
    DumpTree(Node.Children[True], I, Mask);
  end;
end;

procedure ProfilerThreadProc(MainThread: THandle); stdcall;
var
  StartTicks: Cardinal;
  Context: TContext;
  Stack: TCallStack;
begin
  while GetKeyState(VK_CANCEL)>=0 do Sleep(1);
  
  StartTicks := GetTickCount;
  while GetTickCount-StartTicks<10*1000 do
  begin
    FillChar(Context, SizeOf(Context), 0);
    Context.ContextFlags := CONTEXT_CONTROL or CONTEXT_SEGMENTS;
    SuspendThread(MainThread);
    if not GetThreadContext(MainThread, Context) then Break;
    GetCallStack(Context, Stack);
    ResumeThread(MainThread);
    AddCallstack(Stack);
    Sleep(1);
  end;

  Assign(F, 'profile.log');
  ReWrite(F);
  DumpTree(@RootNode, -1, 0);
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
  StackBottom := GetStackBottom;
  Result := False;
  if not DuplicateHandle(GetCurrentProcess, GetCurrentThread, GetCurrentProcess, @MyThread, 0, false, DUPLICATE_SAME_ACCESS) then
    Exit;
  if CreateThread(nil, 0, @ProfilerThreadProc, Pointer(MyThread), 0, ThreadId) = 0 then
    Exit;
  Result := True;
end;

begin
  if not StartProfiler then
    MessageBox(0, 'The profiler couldn''t be started due to an error.', 'wkProfiler2', MB_ICONERROR);
end.
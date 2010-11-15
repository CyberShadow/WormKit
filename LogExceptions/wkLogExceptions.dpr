library wkCrashOnMessageBox;

{$IMAGEBASE $62800000}

uses Windows, USysUtils;

// ***************************************************************

type
  TVectoredExceptionHandler = function(const ExceptionPointers: TExceptionPointers): Integer; stdcall;
  PExceptionPointers = ^TExceptionPointers;
  TMinidumpExceptionInformation = record
    ThreadId: Cardinal;
    ExceptionPointers: PExceptionPointers;
    ClientPointers: LongBool;
  end;
  PMinidumpExceptionInformation = ^TMinidumpExceptionInformation;

const
  EXCEPTION_CONTINUE_SEARCH = 0;

  MiniDumpNormal = $00000000;
  MiniDumpWithDataSegs = $00000001;
  MiniDumpWithFullMemory = $00000002;
  MiniDumpWithHandleData = $00000004;
  MiniDumpFilterMemory = $00000008;
  MiniDumpScanMemory = $00000010;
  MiniDumpWithUnloadedModules = $00000020;
  MiniDumpWithIndirectlyReferencedMemory = $00000040;
  MiniDumpFilterModulePaths = $00000080;
  MiniDumpWithProcessThreadData = $00000100;
  MiniDumpWithPrivateReadWriteMemory = $00000200;
  MiniDumpWithoutOptionalData = $00000400;
  MiniDumpWithFullMemoryInfo = $00000800;
  MiniDumpWithThreadInfo = $00001000;
  MiniDumpWithCodeSegs = $00002000;

function MiniDumpWriteDump(hProcess: THandle; ProcessId: DWORD; hFile: THandle; DumpType: Integer; ExceptionParam: PMinidumpExceptionInformation; UserStreamParam: Pointer; CallbackParam: Pointer): BOOL; stdcall; external 'dbghelp.dll';
function AddVectoredExceptionHandler(FirstHandler: LongBool; VectoredHandler: TVectoredExceptionHandler): Pointer; stdcall; external 'kernel32.dll';

// ***************************************************************

function VectoredExceptionHandler(const ExceptionPointers: TExceptionPointers): Integer; stdcall;
var
  I, Mode: Integer;
  S: string;
  hMiniDumpFile: THandle;
  eInfo: TMinidumpExceptionInformation;
  F: Text;
begin
  I := 0;
  repeat
    S := 'EXC_'+IntToHex(I, 4)+'.DMP';
    Inc(I);
  until not FileExists(S);

  // Add an entry to the description list
  AssignFile(F, 'descript.ion');
  {$I-}
  Append(F);
  {$I+}
  if IOResult<>0 then ReWrite(F);
  Write(F, S, ' ', IntToHex(ExceptionPointers.ExceptionRecord.ExceptionCode, 8), ' @ ', IntToHex(Cardinal(ExceptionPointers.ExceptionRecord.ExceptionAddress), 8), ' ( ');
  for I:=0 to ExceptionPointers.ExceptionRecord.NumberParameters-1 do
    Write(F, IntToHex(ExceptionPointers.ExceptionRecord.ExceptionInformation[I], 8), ' ');
  WriteLn(F, ')');
  CloseFile(F);

  // Create the file
  hMiniDumpFile := CreateFile(
    PChar(S),
    GENERIC_WRITE,
    0,
    nil,
    CREATE_ALWAYS,
    FILE_ATTRIBUTE_NORMAL or FILE_FLAG_WRITE_THROUGH,
    0);

  // Write the minidump to the file
  if hMiniDumpFile <> INVALID_HANDLE_VALUE then
  begin
    eInfo.ThreadId := GetCurrentThreadId;
    eInfo.ExceptionPointers := @ExceptionPointers;
    eInfo.ClientPointers := False;
    if GetKeyState(VK_SHIFT)<0 then
      Mode := MiniDumpWithDataSegs or MiniDumpWithFullMemory or MiniDumpWithHandleData
    else
      Mode := 0;
    MiniDumpWriteDump(GetCurrentProcess, GetCurrentProcessId, hMiniDumpFile, Mode, @eInfo, nil, nil);

    // Close file
    CloseHandle(hMiniDumpFile);
  end;

  Result := EXCEPTION_CONTINUE_SEARCH;
end;

// ***************************************************************

begin
  AddVectoredExceptionHandler(True, @VectoredExceptionHandler);
end.

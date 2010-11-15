library wkMinidumpOnFlush;

{$IMAGEBASE $62800000}

uses Windows, USysUtils, madCodeHook;

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
function RemoveVectoredExceptionHandler(Handler: Pointer): ULONG; stdcall; external 'kernel32.dll';

// ***************************************************************

function VectoredExceptionHandler(const ExceptionPointers: TExceptionPointers): Integer; stdcall;
var
  I, Mode: Integer;
  S: string;
  hMiniDumpFile: THandle;
  eInfo: TMinidumpExceptionInformation;
begin
  I := 0;
  repeat
    S := 'Flush'+IntToHex(I, 3)+'.DMP';
    Inc(I);
  until not FileExists(S);

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

var
  FlushFileBuffersNext: function(hFile: THandle): BOOL; stdcall;
  Reentry: Boolean = False;

// ***************************************************************

function FlushFileBuffersCallback(hFile: THandle): BOOL; stdcall; assembler;
var
  Handler: Pointer;
begin
  if not Reentry then
  begin
    Reentry := True;

    Handler := AddVectoredExceptionHandler(True, @VectoredExceptionHandler);
    try
      PInteger(nil)^ := 0;
    except
    end;
    RemoveVectoredExceptionHandler(Handler);

    Reentry := False;
  end;
  Result := FlushFileBuffersNext(hFile);
end;

// ***************************************************************

begin
  HookAPI('kernel32.dll', 'FlushFileBuffers', @FlushFileBuffersCallback, @FlushFileBuffersNext);
end.

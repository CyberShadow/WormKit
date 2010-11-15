library wkMinidumpAfter5Minutes;

{$IMAGEBASE $62800000}

uses Windows;

// ***************************************************************

function MiniDumpWriteDump(hProcess: THandle; ProcessId: DWORD; hFile: THandle; DumpType: Integer; ExceptionParam: Pointer; UserStreamParam: Pointer; CallbackParam: Pointer): BOOL; stdcall; external 'dbghelp.dll' name 'MiniDumpWriteDump';

// ***************************************************************

procedure ThreadProc(Nothing: Pointer); stdcall;
var
  hMiniDumpFile: THandle;
begin
  //while (GetKeyState(VK_CONTROL)>=0) or (GetKeyState(VK_PAUSE)>=0) do Sleep(1);
  while GetKeyState(VK_CANCEL)>=0 do Sleep(1);

  // Create the file
  hMiniDumpFile := CreateFile(
    'FREEZE.DMP',
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

  TerminateProcess(GetCurrentProcess, 12345);
end;

// ***************************************************************

var
  ThreadID: Cardinal;

begin
  CreateThread(nil, 0, @ThreadProc, nil, 0, ThreadID);
end.

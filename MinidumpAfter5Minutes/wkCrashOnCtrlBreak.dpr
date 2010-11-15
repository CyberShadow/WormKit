library wkMinidumpAfter5Minutes;

{$IMAGEBASE $62800000}

uses Windows;

// ***************************************************************

procedure ThreadProc(Nothing: Pointer); stdcall;
begin
  while GetKeyState(VK_CANCEL)>=0 do Sleep(1);
  asm int 3 end;
end;

// ***************************************************************

var
  ThreadID: Cardinal;

begin
  CreateThread(nil, 0, @ThreadProc, nil, 0, ThreadID);
end.

library wkCrashOnMessageBox;

{$IMAGEBASE $62800000}

uses Windows, USysUtils, madCodeHook;

// ***************************************************************

var
  MessageBoxANext: function(hWnd: HWND; lpText, lpCaption: PAnsiChar; uType: UINT): Integer; stdcall;

// ***************************************************************

function MessageBoxACallback(hWnd: HWND; lpText, lpCaption: PAnsiChar; uType: UINT): Integer; stdcall;
begin
  //Result := MessageBoxANext(hWnd, lpText, lpCaption, uType);
  asm int 3 end;
end;

// ***************************************************************

begin
  HookAPI('user32.dll', 'MessageBoxA', @MessageBoxACallback, @MessageBoxANext);
end.

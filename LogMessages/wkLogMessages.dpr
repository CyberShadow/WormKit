library wkLogMessages;

{$IMAGEBASE $62800000}

uses Windows, Messages, USysUtils;

// ***************************************************************

procedure Log(S: string);
var
  F: Text;
begin
  Assign(F, 'wkLogMessages.log');
  {$I-}
  Append(F);
  if IOResult<>0 then 
    ReWrite(F);
  WriteLn(F, '[' + TimeStr + '] ' + S);
  Close(F);
  {$I+}
  IOResult;
end;

{$INCLUDE 'msgnames.inc'}

function MessageName(Msg: DWORD): String;
var
  I: Integer;
  Buf: array[0..1024] of Char;
begin
  if (Msg>=WM_USER) and (Msg<$8000) then
    Result := 'WM_USER+'+IntToHex(Msg-WM_USER, 4)
  else
  if (Msg>=WM_APP) and (Msg<$C000) then
    Result := 'WM_APP+'+IntToHex(Msg-WM_APP, 4)
  else
  if (Msg>=$C000) and (Msg<$10000) then
  begin
    GetClipboardFormatName(Msg, Buf, 1024);
    Result := PChar(@Buf[0]);
  end
  else
  begin
    for I:=1 to High(MsgNames) do
      if Cardinal(MsgNames[I].Value)=Msg then
      begin
        Result := MsgNames[I].Name;
        Exit
      end;
    Result := IntToHex(Msg, 8);
  end;
end;

procedure ProcessMessage(var lpMsg: TMsg);
begin
  if (GetKeyState(VK_SCROLL) and 1)<>0 then
    Log(IntToHex(lpMsg.hwnd, 8) + ' ' + MessageName(lpMsg.message) + ' (' + IntToHex(lpMsg.wParam, 8) + ', ' + IntToHex(lpMsg.lParam, 8) + ')');
end;

var
  Hook: HHOOK;

function GetMsgProc(Code: Integer; wParam, lParam: Cardinal): LRESULT; stdcall;
begin
  if Code=HC_ACTION then
    if wParam=PM_REMOVE then
      ProcessMessage(PMsg(lParam)^);
  Result := CallNextHookEx(Hook, Code, lParam, wParam);
end;

begin
  Hook := SetWindowsHookEx(WH_GETMESSAGE, @GetMsgProc, 0, GetCurrentThreadId);
  if Hook=0 then
    MessageBox(0, 'wkLogMessages hook error', nil, 0);
end.

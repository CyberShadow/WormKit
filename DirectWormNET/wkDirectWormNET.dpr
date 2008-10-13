library wkDirectWormNET;

{$IMAGEBASE $63800000}

uses 
  Windows;

const
  BusyRect: TRect =                        (Left:137;Top:182; Right:503;Bottom:297);
  Paths: array [1..5, 1..2] of TRect = (
    ((Left:0;Top:0; Right:645;Bottom:483), (Left: 71;Top:267; Right:311;Bottom:417)),
    ((Left:0;Top:0; Right:645;Bottom:483), (Left:350;Top: 44; Right:590;Bottom:194)),
    ((Left:0;Top:0; Right:641;Bottom:481), (Left: 10;Top:440; Right:473;Bottom:475)),
    ((Left:0;Top:0; Right:641;Bottom:481), (Left: 10;Top: 40; Right:630;Bottom:166)),
    ((Left:0;Top:0; Right:641;Bottom:481), (Left:510;Top: 15; Right:630;Bottom: 35)));

function FindWindowRect(Parent: THandle; const Rect: TRect): THandle;
var
  h: THandle;
  R: TRect;
begin
  Result:=0;
  h:=FindWindowEx(Parent, 0, nil, nil);
  while h<>0 do
    begin
    GetWindowRect(h, R);
    if IsWindowVisible(h) then
      if(R.Left  =Rect.Left  )and
        (R.Top   =Rect.Top   )and
        (R.Right =Rect.Right )and
        (R.Bottom=Rect.Bottom)then
        begin
        Result:=h;
        Exit
        end;
    h:=FindWindowEx(Parent, h, nil, nil);
    end;
end;

var
  Phase: Integer = 0;

procedure MainProc(Nothing: Pointer); stdcall;
var
  State, I: Integer;
  h: hWnd;
begin
  repeat
    Sleep(100);
    if GetKeyState(VK_SHIFT)<0 then
      Exit;

    if FindWindowRect(0, BusyRect)<>0 then
      Continue;
    State:=0;
    for I:=5 downto 1 do
      begin
      h:=FindWindowRect(0, Paths[I,1]);
      if h<>0 then
        h:=FindWindowRect(h, Paths[I,2]);
      if h<>0 then
        begin
        State:=I;
        Break
        end;
      end;
    if State<>0 then
      begin
      if State<Phase then
        Exit;
      Phase:=State;
      case Phase of
        1:begin
          SetCursorPos(191, 342);  // move the mouse
          Sleep(10);
          mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);  // press left button
          Sleep(10);
          mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);  // release left button
          Sleep(10);
          end;
        2:begin
          SetCursorPos(470, 119);  // move the mouse
          Sleep(10);
          mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);  // press left button
          Sleep(10);
          mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);  // release left button
          Sleep(10);
          end;
        3:begin
          SetCursorPos(320, 185);  // move the mouse
          Sleep(10);
          mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);  // press left button
          Sleep(10);
          mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);  // release left button
          Sleep(10);
          mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);  // press left button (again)
          Sleep(10);
          mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);  // release left button (again)
          Sleep(10);
  
          SetCursorPos(450, 280);  // move the mouse
          Sleep(10);
          mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);  // press left button
          Sleep(10);
          mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);  // release left button
          Sleep(10);
          mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);  // press left button (again)
          Sleep(10);
          mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);  // release left button (again)
          Sleep(10);
          end;
        4:begin
          if not IsWindowEnabled(h) then
            Continue;
          SetCursorPos(50, 80);  // move the mouse
          Sleep(10);
          mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);  // press left button
          Sleep(10);
          mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);  // release left button
          Sleep(10);
          mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);  // press left button (again)
          Sleep(10);
          mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);  // release left button (again)
          Sleep(10);
          end;
        5:begin
          SetCursorPos(570, 30);  // move the mouse
          Exit; // sequence complete
          end;
        end;
      end;
  until False;
end;

var
  ThreadID: Cardinal;

begin
  CreateThread(nil, 0, @MainProc, nil, 0, ThreadID);
end.

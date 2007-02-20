unit LingerIRC;  // after Worms closes connection, the host's IRC user must stay online
                 // to relay connection information to other users
interface
uses
  Base, Data, Windows, SysUtils, WinSock;

var
  LingeringIRC: TSocket = 0;

procedure StartLingering;
procedure StopLingering;
function LingeringSendLn(S: string; EOL: string=#13#10): Boolean;

implementation

var
  LingeringThread: THandle;
  Stop, Finished: Boolean;

procedure LingeringProc(Nothing: Pointer); stdcall;
var
  Buffer, S: string;
  R, Bytes: Integer;
  ReadSet: record
    count: u_int;
    Socket: TSocket;
    end;
  TimeVal: TTimeVal;
begin
  Log('[LIRC] Starting the lingering ('+IntToHex(LingeringIRC, 0)+')...');
  if not LingeringSendLn('VERSION') then  // whatever
    Log('[LIRC] Error - can''t write to the socket ('+IntToHex(LingeringIRC, 0)+') !');
  Buffer:='';
  TimeVal.tv_sec:=0;
  TimeVal.tv_usec:=0;
  repeat
    repeat
      ReadSet.count:=1;
      ReadSet.Socket:=LingeringIRC;
      R:=select(0, @ReadSet, nil, nil, @TimeVal);
      if R=SOCKET_ERROR then
        begin
        Log('[LIRC] Connection error ('+IntToStr(WSAGetLastError)+') in select().');
        Finished:=True;
        Exit;
        end;

      if (ReadSet.count=0)or(R=0) then
        Break;         // nothing to read

      R:=ioctlsocket(LingeringIRC, FIONREAD, Bytes);
      if R=SOCKET_ERROR then
        begin
        Log('[LIRC] Connection error ('+IntToStr(WSAGetLastError)+').');
        Finished:=True;
        Exit;
        end;
      if Bytes=0 then
        begin
        Log('[LIRC] Graceful disconnect.');
        Finished:=True;
        Exit;
        end;
      SetLength(S, Bytes);
      R:=recv(LingeringIRC, S[1], Bytes, 0);
      if(R=0)or(R=SOCKET_ERROR)then
        begin
        Log('[LIRC] Connection error ('+IntToStr(WSAGetLastError)+').');
        Finished:=True;
        Exit;
        end;
      SetLength(S, R);
      Buffer := Buffer + S;
    until False;

    while GetLine(Buffer, S) do
      begin     // :CyberShadow!cybershado@2e01205d.2e099bf0.35556308.18251e65X NOTICE CyberShadow :bla bla test
      if Pos(':WormNAT!WormNAT@wormnat.xeon.cc', S)=0 then
        Log('[LIRC < ] '+S, 1);
      if Copy(S, 1, 4)='PING' then
        LingeringSendLn('PONG'+Copy(S, 5, 1000));
      end;

    // the hooks should handle the rest of the I/O
    Sleep(10);
  until Stop;
  Log('[LIRC] Stopping.');
  LingeringSendLn('QUIT');
  closesocket(LingeringIRC);
  Finished:=True;
end;

procedure StartLingering;
var 
  ThreadID: Cardinal;
begin
  if LingeringThread<>0 then
    StopLingering;
  LingeringThread:=CreateThread(nil, 0, @LingeringProc, nil, 0, ThreadID);
  Stop:=False;
  Finished:=False;
end;

procedure StopLingering;
var 
  C: Integer;
begin
  if(LingeringIRC<>0)and(LingeringThread<>0) then
    try
      begin
      Stop:=True;
      C:=0;
      repeat
        Sleep(10); Inc(C);
      until(C=50)or Finished;

      if not Finished then
        begin
        Log('[LIRC] Oops, the lingering is stuck, killing...');
        TerminateThread(LingeringThread, 0);
        LingeringSendLn('QUIT');
        closesocket(LingeringIRC);
        Finished:=True;
        end;
      Sleep(250); // give the server some time to realize we QUIT
      end;
  except
    on E: Exception do
      begin
      Log('[LIRC] Error while terminating the lingering: '+E.Message);
      end;
    end;
  LingeringIRC:=0;
  LingeringThread:=0;
end;

function LingeringSendLn(S: string; EOL: string=#13#10): Boolean;
begin
  S:=S+EOL;
  Result:=send(LingeringIRC, S[1], Length(S), 0) = Length(S);
  while Copy(S, Length(S)-1, 2)=#13#10 do
    S:=Copy(S, 1, Length(S)-2);
  Log('[LIRC > ] '+S, 1);
  if not Result then
    Log('[LIRC > Failed ('+IntToStr(WSAGetLastError)+') ]');
end;

end.
unit Main;
// main Packets library code

interface

uses 
  Packets;

procedure SubscribeToBeforeConnect(P: TConnectSubscriptionProc);
procedure SubscribeToConnect(P: TConnectSubscriptionProc);
procedure SubscribeToBeforeDisconnect(P: TBeforeDisconnectSubscriptionProc);
procedure SubscribeToDisconnect(P: TDisconnectSubscriptionProc);
procedure SubscribeToRaw(P: TRawSubscriptionProc);
procedure SubscribeToPackets(P: TPacketSubscriptionProc);
procedure SubscribeToLobby(P: TLobbySubscriptionProc);
//procedure SubscribeToGame(P: TGameSubscriptionProc);

procedure SubscribeToIRC(PIn, POut: TTextSubscriptionProc);
procedure SubscribeToHTTP(PIn, POut: TTextSubscriptionProc);
procedure SubscribeToOther(P: TRawSubscriptionProc); 

procedure SubscribeToResolve(P: TResolveSubscriptionProc);

procedure DisableHooks;
procedure ReenableHooks;

function GetConnections: TConnectionArray;
function IsPacketsInitialized: Boolean;

var
  BeforeConnectSubscriptions, 
  ConnectSubscriptions: array of TConnectSubscriptionProc;
  DisconnectSubscriptions: array of TDisconnectSubscriptionProc;
  BeforeDisconnectSubscriptions: array of TBeforeDisconnectSubscriptionProc;

  RawSubscriptions: array of TRawSubscriptionProc;
  PacketSubscriptions: array of TPacketSubscriptionProc;
  LobbySubscriptions: array of TLobbySubscriptionProc;
  //GameSubscriptions: array of TGameSubscriptionProc;

  IRCInSubscriptions, IRCOutSubscriptions, 
  HTTPInSubscriptions, HTTPOutSubscriptions: array of TTextSubscriptionProc;
  OtherSubscriptions: array of TRawSubscriptionProc;

  ResolveSubscriptions: array of TResolveSubscriptionProc;

implementation

uses 
  Windows, USysUtils, UExceptions, WinSock, madCHook, Base;

// ***************************************************************

var 
  connectNext : function (s: TSocket; name: PSockAddrIn; NameLen: Integer) : Integer;  stdcall;
  acceptNext : function(s: TSocket; addr: PSockAddr; addrlen: PInteger): TSocket; stdcall;
  WSAAcceptNext: function(s: TSocket; addr: PSockAddr; addrlen: PInteger; lpfnCondition: Pointer; dwCallbackData: DWORD): TSocket; stdcall;
  sendNext : function (s: TSocket; var Buf; len, flags: Integer): Integer; stdcall;
  recvNext : function (s: TSocket; var Buf; len, flags: Integer): Integer; stdcall;
  ioctlsocketNext : function(s: TSocket; cmd: DWORD; var arg: u_long): Integer; stdcall;
  closesocketNext : function(s: TSocket): Integer; stdcall;
  gethostbynameNext : function (name: PChar): PHostEnt; stdcall;
  WSAAsyncSelectNext : function (s: TSocket; HWindow: HWND; wMsg: u_int; lEvent: Longint): Integer; stdcall;

  AsyncMessageWindow: hWnd;
  AsyncMessage: Integer;
  AsyncEvents: Integer;

  HookLevel: Integer;

  Connections: TConnectionArray;
  PendingGameConnections: array of TSocket;

// ***************************************************************

function IsSocketWritable(Socket: TSocket): Boolean;
var
  WriteSet: record
    count: u_int;
    Socket: TSocket;
  end;
  TimeVal: TTimeVal;
  R: Integer;
begin
  TimeVal.tv_sec:=0;
  TimeVal.tv_usec:=0;

  WriteSet.count:=1;
  WriteSet.Socket:=Socket;
  R:=select(Socket+1, nil, @WriteSet, nil, @TimeVal);
  Result:=(R=1)and(WriteSet.count=1);
end;

function FindConnection(Socket: TSocket): PConnection;
var
  I: Integer;
begin
  Result:=nil;
  for I:=0 to High(Connections) do
    if Connections[I]^.Socket=Socket then
      Result:=Connections[I];
end;

// ***************************************************************

function DetectConnectionType(Data: string): TConnectionType; // VP 2008.11.06: identify connections to unknown ports by the first bytes
begin
  Result := ctUnknown;
  if (Length(Data)>=1) and (Data[1]<>#$01) then
    begin Result := ctOther; Exit end;
  if (Length(Data)>=3) and (Data[3]<>#$80) and (Data[3]<>#$28) then
    begin Result := ctOther; Exit end;
  if (Length(Data)>=4) and (Data[4]<>#$00) and (Data[4]<>#$06) then
    begin Result := ctOther; Exit end;
  if (Length(Data)>=5) and (Data[5]<>#$04) and (Data[5]<>#$0B) then
    begin Result := ctOther; Exit end;
  if (Length(Data)>=6) and (Data[6]<>#$00) then
    begin Result := ctOther; Exit end;

  if Length(Data)>=6 then
    if ((Data[1]=#$01) and
        (Data[3]=#$80) and
        (Data[4]=#$00) and
        (Data[5]=#$04) and
        (Data[6]=#$00)) or
       ((Data[1]=#$01) and
        (Data[3]=#$28) and
        (Data[4]=#$06) and
        (Data[5]=#$0B) and
        (Data[6]=#$00)) then
        Result := ctGame
      else
        Result := ctOther;
end;

procedure ConnectionProc(Connection: PConnection); stdcall;
var
  Mode, R, I, N, Error: Integer;
  Bytes: u_long; 
  Data: string;
  PacketSize: Word;
  GotNewData, SendThis, Disconnected: Boolean;
  ReadSet: record
    count: u_int;
    Socket: TSocket;
  end;
  TimeVal: TTimeVal;
  OldConnectionType: TConnectionType;
begin
  try
    with Connection^ do
    begin
      // remove Async notifications for this socket
      WSAAsyncSelectNext(Socket, AsyncMessageWindow, 0, 0);
      // set the socket to non-blocking mode
      Mode:=0;
      ioctlsocket(Socket, FIONBIO, Mode);
      
      if Direction=dOutgoing then
      begin
        Inc(HookLevel);
        for I:=0 to High(BeforeConnectSubscriptions) do
          BeforeConnectSubscriptions[I](Connection);
        Dec(HookLevel);
        
        if Address.sin_addr.s_addr=0 then
        begin
          PostMessage(AsyncMessageWindow, AsyncMessage, Socket or (WSAEACCES shl 16), FD_CONNECT);
          Exit;
        end;

        R:=connectNext(Socket, @Address, AddressLen);
        if R=SOCKET_ERROR then
        begin
          R:=WSAGetLastError;
          for I:=0 to High(DisconnectSubscriptions) do
            DisconnectSubscriptions[I](Connection, 'connect() error ('+WinSockErrorCodeStr(R)+')');
        end;
        PostMessage(AsyncMessageWindow, AsyncMessage, Socket or (R shl 16), FD_CONNECT);
        if R<>0 then
          Abort;
      end;
      PostMessage(AsyncMessageWindow, AsyncMessage, Socket, FD_WRITE);
      PostMessage(AsyncMessageWindow, AsyncMessage, Socket, FD_READ);

      Phase:=cpLobby;
      Disconnected:=False;
      
      Inc(HookLevel);
      for I:=0 to High(ConnectSubscriptions) do
        ConnectSubscriptions[I](Connection);
      Dec(HookLevel);
      
      repeat
        // check for socket errors
        Error:=0;  N:=SizeOf(Error);
        R:=getsockopt(Socket, SOL_SOCKET, SO_ERROR, PChar(@Error), N);
        if R<>0 then
        begin
          Done:=True;
          for I:=0 to High(DisconnectSubscriptions) do
            DisconnectSubscriptions[I](Connection, 'getsockopt() error ('+WinSockErrorCodeStr(WSAGetLastError)+')');
          Break;
        end;
        if Error<>0 then
        begin
          Done:=True;
          for I:=0 to High(DisconnectSubscriptions) do
            DisconnectSubscriptions[I](Connection, 'socket error ('+WinSockErrorCodeStr(Error)+')');
          Break;
        end;

        OldConnectionType := ConnectionType;
        if ConnectionType=ctUnknown then
          ConnectionType := DetectConnectionType(WriteBufferIn);

        // process data to-be-sent
        if ConnectionType=ctGame then
        begin
          if OldConnectionType=ctUnknown then
          begin
            if WriteBufferIn<>'' then
            begin   // we didn't know it was a game connection in the send hook, process it now
              Inc(HookLevel);
              Data := WriteBufferIn;
              WriteBufferIn := '';
              for I:=0 to High(RawSubscriptions) do
                RawSubscriptions[I](Connection, Data, dOutgoing);
              WriteBufferOut := WriteBufferOut + Data;
              Dec(HookLevel);
            end
          end
          else
          begin
            // we already processed sent game data in the send() hook, so just send the buffer
            WriteBufferOut:=WriteBufferIn;
            WriteBufferIn:='';
          end;
        end
        else
        if ConnectionType=ctIRC then
        begin
          while GetLine(WriteBufferIn, Data) do
          begin
            Inc(HookLevel);
            SendThis:=True;
            for I:=0 to High(IRCOutSubscriptions) do
              SendThis:=SendThis and IRCOutSubscriptions[I](Connection, Data);
            if SendThis then
              WriteBufferOut:=WriteBufferOut+Data+#13#10;
            Dec(HookLevel);
          end;
        end
        else
        if ConnectionType=ctHTTP then
        begin
          while GetLine(WriteBufferIn, Data) do
          begin
            Inc(HookLevel);
            SendThis:=True;
            for I:=0 to High(HTTPOutSubscriptions) do
              SendThis:=SendThis and HTTPOutSubscriptions[I](Connection, Data);
            if SendThis then
              WriteBufferOut:=WriteBufferOut+Data+#13#10;
            Dec(HookLevel);
          end;
        end
        else
        if ConnectionType=ctOther then
        begin
          if WriteBufferIn<>'' then
          begin
            Inc(HookLevel);
            Data := WriteBufferIn;
            WriteBufferIn := '';
            for I:=0 to High(OtherSubscriptions) do
              OtherSubscriptions[I](Connection, Data, dOutgoing);
            WriteBufferOut := WriteBufferOut + Data;
            Dec(HookLevel);
          end;
        end;

        // write buffered data
        while IsSocketWritable(Socket) and (WriteBufferOut<>'') do
        begin
          Bytes:=sendNext(Socket, WriteBufferOut[1], Length(WriteBufferOut), 0);
          if Bytes=SOCKET_ERROR then
          begin
            Done:=True;
            for I:=0 to High(DisconnectSubscriptions) do
              DisconnectSubscriptions[I](Connection, 'send() error ('+WinSockErrorCodeStr(WSAGetLastError)+')');
            Break;
          end;
          Delete(WriteBufferOut, 1, Bytes);
          if WriteBufferOut='' then
            PostMessage(AsyncMessageWindow, AsyncMessage, Socket, FD_WRITE);
        end;
        
        // read data from the socket
        repeat
          TimeVal.tv_sec:=0;
          TimeVal.tv_usec:=0;

          ReadSet.count:=1;
          ReadSet.Socket:=Socket;
          R:=select(Socket+1, @ReadSet, nil, nil, @TimeVal);
          if R=SOCKET_ERROR then
          begin
            Done:=True;
            for I:=0 to High(DisconnectSubscriptions) do
              DisconnectSubscriptions[I](Connection, 'select() error ('+WinSockErrorCodeStr(WSAGetLastError)+')');
            Break;
          end;

          if (ReadSet.count<>R) or (R>1) or (R<0) then
          begin
            Done:=True;
            for I:=0 to High(DisconnectSubscriptions) do
              DisconnectSubscriptions[I](Connection, 'ioctlsocket() error (strange values: ReadSet.count='+IntToStr(ReadSet.count)+' R='+IntToStr(R)+')');
            Break;
          end;

          if (ReadSet.count=0) or (R=0) then
            Break;         // nothing to read

          R := ioctlsocketNext(Socket, FIONREAD, Bytes);
          if R=SOCKET_ERROR then
          begin
            Done:=True;
            for I:=0 to High(DisconnectSubscriptions) do
              DisconnectSubscriptions[I](Connection, 'ioctlsocket() error ('+WinSockErrorCodeStr(WSAGetLastError)+')');
            Break;
          end;

          if Bytes=0 then 
          begin
            Bytes := recvNext(Socket, Bytes, 0, 0);
            if Bytes=SOCKET_ERROR then 
            begin
              Done:=True;
              for I:=0 to High(DisconnectSubscriptions) do
                DisconnectSubscriptions[I](Connection, 'connection error ('+WinSockErrorCodeStr(WSAGetLastError)+')');
              Break;
            end;

            // process graceful disconnects after data
            Disconnected:=True;
            Break;
          end;

          SetLength(Data, Bytes);
          Bytes := recvNext(Socket, Data[1], Bytes, 0);
          if Bytes=0 then            // huh?
          begin
            Done:=True;
            for I:=0 to High(DisconnectSubscriptions) do
              DisconnectSubscriptions[I](Connection, '(sort of) graceful disconnect');
            Break;
          end;
          if Bytes=SOCKET_ERROR then 
          begin
            Done:=True;
            for I:=0 to High(DisconnectSubscriptions) do
              DisconnectSubscriptions[I](Connection, 'recv() error ('+WinSockErrorCodeStr(WSAGetLastError)+')');
            Break;
          end;
          SetLength(Data, Bytes);
          ReadBufferIn:=ReadBufferIn+Data;
        until False;

        if ConnectionType=ctUnknown then
          ConnectionType := DetectConnectionType(ReadBufferIn);

        // process data
        GotNewData:=False;
        if ConnectionType=ctGame then
        begin
          repeat
            if Length(ReadBufferIn)<4 then
              Break;
            Move(ReadBufferIn[3], PacketSize, 2);
            if Length(ReadBufferIn)<PacketSize then
              Break;
            Data:=Copy(ReadBufferIn, 1, PacketSize);
            Delete(ReadBufferIn, 1, PacketSize);
            
            Inc(HookLevel);
            for I:=0 to High(RawSubscriptions) do
              RawSubscriptions[I](Connection, Data, dIncoming);
            Dec(HookLevel);

            ReadBufferOut:=ReadBufferOut+Data;
            GotNewData:=True;
          until False;
        end
        else
        if ConnectionType=ctIRC then
        begin
          if (ReadBufferIn<>'') and (Copy(ReadBufferIn, Length(ReadBufferIn)-1, 2)<>#13#10) and Disconnected then
            ReadBufferIn:=ReadBufferIn+#13#10;
          while GetLine(ReadBufferIn, Data) do
          begin
            Inc(HookLevel);
            SendThis:=True;
            for I:=0 to High(IRCInSubscriptions) do
              SendThis:=SendThis and IRCInSubscriptions[I](Connection, Data);
            if SendThis then
              ReadBufferOut:=ReadBufferOut+Data+#13#10;
            Dec(HookLevel);
            GotNewData:=True;
          end;
        end
        else
        if ConnectionType=ctHTTP then
        begin
          if (ReadBufferIn<>'') and (Copy(ReadBufferIn, Length(ReadBufferIn)-1, 2)<>#13#10) and Disconnected then
            ReadBufferIn:=ReadBufferIn+#13#10;
          while GetLine(ReadBufferIn, Data) do
          begin
            Inc(HookLevel);
            SendThis:=True;
            for I:=0 to High(HTTPInSubscriptions) do
              SendThis:=SendThis and HTTPInSubscriptions[I](Connection, Data);
            if SendThis then
              ReadBufferOut:=ReadBufferOut+Data+#13#10;
            Dec(HookLevel);
            GotNewData:=True;
          end;
        end
        else
        if ConnectionType=ctOther then
        begin
          if ReadBufferIn<>'' then
          begin
            Inc(HookLevel);
            Data := ReadBufferIn;
            ReadBufferIn := '';
            for I:=0 to High(OtherSubscriptions) do
              OtherSubscriptions[I](Connection, Data, dIncoming);
            ReadBufferOut := ReadBufferOut + Data;
            Dec(HookLevel);
            if Length(Data)>0 then
              GotNewData := True;
          end;
        end;
        if GotNewData or NewReadData then
          PostMessage(AsyncMessageWindow, AsyncMessage, Socket, FD_READ);
        NewReadData:=False;

        
        if Disconnected then   // process graceful disconnects after data
        begin
          //if (GotNewData) then begin MessageBeep(MB_ICONERROR); Sleep(250); MessageBeep(MB_ICONERROR); Sleep(250); MessageBeep(MB_ICONERROR); Sleep(250); end;
          Inc(HookLevel);
          for I:=0 to High(DisconnectSubscriptions) do
            DisconnectSubscriptions[I](Connection, 'graceful disconnect');
          Dec(HookLevel);
          Done:=True;
        end;

        Sleep(1);
      until Done;

    end;
  except
    on E: EAbort do
      ;
    on E: Exception do
      MessageBox(0, PChar(E.Message), 'wkPackets error', MB_ICONERROR);
  end;
  
  while Length(Connection.ReadBufferOut)>0 do
    Sleep(1);

  if Connection.Socket<>0 then
  begin
    closesocketNext(Connection.Socket);
    PostMessage(AsyncMessageWindow, AsyncMessage, Connection.Socket, FD_CLOSE);
  end;

  N:=-1;
  for I:=0 to High(Connections) do
    if Connections[I]=Connection then
      N:=I;
  if N<>-1 then
  begin
    for I:=N+1 to High(Connections) do
      Connections[I-1]:=Connections[I];
    SetLength(Connections, Length(Connections)-1);
  end;
  Dispose(Connection);
end;

// ***************************************************************

function IsGameConnection(s: TSocket): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I:=0 to High(PendingGameConnections) do
    if PendingGameConnections[I]=s then
    begin
      PendingGameConnections[I] := 0;
      Result := True;
      Exit;
    end;
end;

function connectCallback(s: TSocket; name: PSockAddrIn; NameLen: Integer) : Integer; stdcall;
var
  LConnectionType: TConnectionType;
  I: Integer;
begin
  if (HookLevel>0) or not IsGameConnection(s) then
  begin
    Result:=connectNext(s, name, NameLen);
    Exit;
  end;

  for I:=0 to High(Connections) do  // socket reuse...
    if Connections[I].Socket=s then
    begin
      Connections[I].Socket:=0;
      Connections[I].Done:=True;
    end;

  if ntohs(name.sin_port)=80 then
    LConnectionType:=ctHTTP
  else
  if (ntohs(name.sin_port)=6666) or
     (ntohs(name.sin_port)=6667) or
     (ntohs(name.sin_port)=6677) then
    LConnectionType:=ctIRC
  else
    LConnectionType:=ctUnknown;  // will be determined by first few bytes
  {begin
    Result:=connectNext(s, name, NameLen);
    Exit;
  end;}
  SetLength(Connections, Length(Connections)+1);
  New(Connections[High(Connections)]);
  FillChar(Connections[High(Connections)]^, SizeOf(TConnection), 0);
  with Connections[High(Connections)]^ do
  begin
    ConnectionType:=LConnectionType;
    Socket:=s;
    Direction:=dOutgoing;
    Phase:=cpConnect;
    Address:=name^;
    AddressLen:=NameLen;
    ThreadHandle:=CreateThread(nil, 0, @ConnectionProc, Connections[High(Connections)], 0, ThreadID);
  end;
  Result:=SOCKET_ERROR;
  WSASetLastError(WSAEWOULDBLOCK);
end;

// ***************************************************************

// VP 2009.06.16: for both accept and WSAAccept
procedure OnAcceptedConnection(AcceptedSocket: TSocket; addr: PSockAddr; addrlen: PInteger);
var
  MyAddr: TSockAddr;
  MyAddrLen: Integer;
begin
  if HookLevel>0 then Exit;
  if (AcceptedSocket=0) or (AcceptedSocket=INVALID_SOCKET) or (AcceptedSocket=SOCKET_ERROR) then Exit;
  if addr=nil then
  begin
    MyAddrLen:=SizeOf(MyAddr);
    getpeername(AcceptedSocket, MyAddr, MyAddrLen);
    addr:=@MyAddr;
    addrlen:=@MyAddrLen;
  end;
  SetLength(Connections, Length(Connections)+1);
  New(Connections[High(Connections)]);
  FillChar(Connections[High(Connections)]^, SizeOf(TConnection), 0);
  with Connections[High(Connections)]^ do
  begin
    ConnectionType:=ctGame;
    Socket:=AcceptedSocket;
    Direction:=dIncoming;
    Phase:=cpConnect;
    Address:=addr^;
    AddressLen:=addrlen^;
    ThreadHandle:=CreateThread(nil, 0, @ConnectionProc, Connections[High(Connections)], 0, ThreadID);
  end;
end;

function acceptCallback(s: TSocket; addr: PSockAddr; addrlen: PInteger): TSocket; stdcall;
begin
  Result:=acceptNext(s, addr, addrlen);
  OnAcceptedConnection(Result, addr, addrlen);
end;

function WSAAcceptCallback(s: TSocket; addr: PSockAddr; addrlen: PInteger; lpfnCondition: Pointer; dwCallbackData: DWORD): TSocket; stdcall;
begin
  Result := WSAAcceptNext(s, addr, addrlen, lpfnCondition, dwCallbackData);
  OnAcceptedConnection(Result, addr, addrlen);
end;

// ***************************************************************

function sendCallback(s: TSocket; var Buf; len, flags: Integer): Integer; stdcall;
var
  I, J: Integer;
  Data: string;
begin
  for I:=0 to High(Connections) do
    if Connections[I].Socket=s then
    begin
      if(Connections[I].WriteBufferIn<>'')or(Connections[I].WriteBufferOut<>'')or not IsSocketWritable(s) then
      begin
        Result:=SOCKET_ERROR;
        WSASetLastError(WSAEWOULDBLOCK);
        Exit;
      end;
      SetLength(Data, len);
      Move(Buf, Data[1], len);
      if (HookLevel=0) and (Connections[I].ConnectionType=ctGame) then
      begin              // game packets are sent one at a time, we can process them right here
        Inc(HookLevel);      // without having to split them later
        for J:=0 to High(RawSubscriptions) do
          RawSubscriptions[J](Connections[I], Data, dOutgoing);
        Dec(HookLevel);
      end;
      Connections[I].WriteBufferIn:=Connections[I].WriteBufferIn+Data;
      Result:=len;
      Exit;
    end;
  Result:=sendNext(s, Buf, len, flags);
end;

// ***************************************************************

function recvCallback(s: TSocket; var Buf; len, flags: Integer): Integer; stdcall;
var
  I: Integer;
begin
  for I:=0 to High(Connections) do
   with Connections[I]^ do
    if Socket=s then
    begin
      if ReadBufferOut='' then
      begin
        Result:=SOCKET_ERROR;
        WSASetLastError(WSAEWOULDBLOCK);
        Exit;
      end;
      if len>Length(ReadBufferOut) then
        len:=Length(ReadBufferOut);
      Move(ReadBufferOut[1], Buf, len);
      Delete(ReadBufferOut, 1, len);
      Result:=len;
      if Length(ReadBufferOut)>0 then
        PostMessage(AsyncMessageWindow, AsyncMessage, Socket, FD_READ);
      Exit;
    end;
  Result:=recvNext(s, Buf, len, flags);
end;

// ***************************************************************

function ioctlsocketCallback(s: TSocket; cmd: DWORD; var arg: u_long): Integer; stdcall;
var
  I: Integer;
begin
  for I:=0 to High(Connections) do
   with Connections[I]^ do
    if Socket=s then
    begin
      if cmd=FIONREAD then  // FIONREAD, get # bytes to read
      begin
        Result:=0;
        arg:=Length(ReadBufferOut);
        Exit;
      end;
    end;
  Result:=ioctlsocketNext(s, cmd, arg);
end;

// ***************************************************************

function closesocketCallback(s: TSocket): Integer; stdcall;
var
  I, J: Integer;
  DoDisconnect: Boolean;
begin
  DoDisconnect:=True;
  for I:=0 to High(Connections) do
    if Connections[I]^.Socket=s then
    begin
      Connections[I]^.Done:=True;
      for J:=0 to High(DisconnectSubscriptions) do
        DisconnectSubscriptions[J](Connections[I], 'connection terminated locally');
      for J:=0 to High(BeforeDisconnectSubscriptions) do
        DoDisconnect:=DoDisconnect and BeforeDisconnectSubscriptions[J](Connections[I]);
    end;
  if DoDisconnect then
    Result:=closesocketNext(s)
  else
    Result:=0;
end;

// ***************************************************************

function gethostbynameCallback(name: PChar): PHostEnt; stdcall;
var
  I: Integer;
begin
  Result:=nil;
  if HookLevel=0 then
  begin
    Inc(HookLevel);
    for I:=0 to High(ResolveSubscriptions) do
      ResolveSubscriptions[I](name, Result);
    Dec(HookLevel);
  end;
  if Result=nil then
    Result:=gethostbynameNext(name);
end;

// ***************************************************************

function WSAAsyncSelectCallback (s: TSocket; HWindow: HWND; wMsg: u_int; lEvent: Longint): Integer; stdcall;
var
  I: Integer;
begin
  for I:=0 to High(Connections) do
    if Connections[I].Socket=s then
    begin
      Result:=0;
      Exit
    end;
  
  SetLength(PendingGameConnections, Length(PendingGameConnections)+1);
  PendingGameConnections[High(PendingGameConnections)] := s;
  
  //if(AsyncMessageWindow<>0)and(AsyncMessageWindow<>HWindow) then   MessageBox(0, 'AsyncMessageWindow changed!', nil, 0);
  //if(AsyncMessage      <>0)and(AsyncMessage      <>wMsg   ) then   MessageBox(0, 'AsyncMessage       changed!', nil, 0);
  //if(AsyncEvents       <>0)and(AsyncEvents       <>lEvent ) then   MessageBox(0, 'AsyncEvents        changed!', nil, 0);
  AsyncMessageWindow:=HWindow;
  AsyncMessage:=wMsg;
  AsyncEvents:=lEvent;
  Result:=WSAAsyncSelectNext(s, HWindow, wMsg, lEvent);
end;

// ***************************************************************

procedure SubscribeToBeforeConnect(P: TConnectSubscriptionProc);
begin SetLength(BeforeConnectSubscriptions, Length(BeforeConnectSubscriptions)+1); BeforeConnectSubscriptions[High(BeforeConnectSubscriptions)]:=P; end;

procedure SubscribeToConnect(P: TConnectSubscriptionProc);
begin SetLength(ConnectSubscriptions, Length(ConnectSubscriptions)+1); ConnectSubscriptions[High(ConnectSubscriptions)]:=P; end;

procedure SubscribeToBeforeDisconnect(P: TBeforeDisconnectSubscriptionProc);
begin SetLength(BeforeDisconnectSubscriptions, Length(BeforeDisconnectSubscriptions)+1); BeforeDisconnectSubscriptions[High(BeforeDisconnectSubscriptions)]:=P; end;

procedure SubscribeToDisconnect(P: TDisconnectSubscriptionProc);
begin SetLength(DisconnectSubscriptions, Length(DisconnectSubscriptions)+1); DisconnectSubscriptions[High(DisconnectSubscriptions)]:=P; end;

procedure SubscribeToRaw(P: TRawSubscriptionProc);
begin SetLength(RawSubscriptions, Length(RawSubscriptions)+1); RawSubscriptions[High(RawSubscriptions)]:=P; end;

procedure SubscribeToPackets(P: TPacketSubscriptionProc);
begin SetLength(PacketSubscriptions, Length(PacketSubscriptions)+1); PacketSubscriptions[High(PacketSubscriptions)]:=P; end;

procedure SubscribeToLobby(P: TLobbySubscriptionProc);
begin SetLength(LobbySubscriptions, Length(LobbySubscriptions)+1); LobbySubscriptions[High(LobbySubscriptions)]:=P; end;

//procedure SubscribeToGame(P: TGameSubscriptionProc);
//begin SetLength(GameSubscriptions, Length(GameSubscriptions)+1); GameSubscriptions[High(GameSubscriptions)]:=P; end;

procedure SubscribeToIRC(PIn, POut: TTextSubscriptionProc);
begin
  if @PIn<>nil then
    begin SetLength(IRCInSubscriptions, Length(IRCInSubscriptions)+1); IRCInSubscriptions[High(IRCInSubscriptions)]:=PIn; end;
  if @POut<>nil then
    begin SetLength(IRCOutSubscriptions, Length(IRCOutSubscriptions)+1); IRCOutSubscriptions[High(IRCOutSubscriptions)]:=POut; end;
end;

procedure SubscribeToHTTP(PIn, POut: TTextSubscriptionProc);
begin
  if @PIn<>nil then
    begin SetLength(HTTPInSubscriptions, Length(HTTPInSubscriptions)+1); HTTPInSubscriptions[High(HTTPInSubscriptions)]:=PIn; end;
  if @POut<>nil then
    begin SetLength(HTTPOutSubscriptions, Length(HTTPOutSubscriptions)+1); HTTPOutSubscriptions[High(HTTPOutSubscriptions)]:=POut; end;
end;

procedure SubscribeToOther(P: TRawSubscriptionProc); 
begin SetLength(OtherSubscriptions, Length(OtherSubscriptions)+1); OtherSubscriptions[High(OtherSubscriptions)]:=P; end;

procedure SubscribeToResolve(P: TResolveSubscriptionProc);
begin SetLength(ResolveSubscriptions, Length(ResolveSubscriptions)+1); ResolveSubscriptions[High(ResolveSubscriptions)]:=P; end;

// ***************************************************************

procedure DisableHooks;
begin
  Inc(HookLevel);
end;

procedure ReenableHooks;
begin
  if HookLevel>0 then
    Dec(HookLevel);
end;

// ***************************************************************

function GetConnections: TConnectionArray;
begin
  Result := Connections;
end;

var
  Initialized: Boolean = False;

function IsPacketsInitialized: Boolean;
begin
  Result := Initialized;
end;

procedure SetAffinity; // hack
var
  H: THandle;
  Mask, SMask: DWORD;
  I: Integer;
begin
  H := GetCurrentProcess();
  if GetProcessAffinityMask(H, Mask, SMask) then
    for I := 0 to 31 do
      if (Mask and (1 shl I))<>0 then
      begin
        Mask := 1 shl I;
        SetProcessAffinityMask(H, Mask);
        Break;
      end;
end;

begin
  Initialized :=
    HookAPI('wsock32.dll',   'connect',       @connectCallback,       @connectNext) and
    HookAPI('wsock32.dll',   'accept',        @acceptCallback,        @acceptNext) and
    HookAPI('ws2_32.dll',    'WSAAccept',     @WSAAcceptCallback,     @WSAAcceptNext) and
    HookAPI('wsock32.dll',   'send',          @sendCallback,          @sendNext) and
    HookAPI('wsock32.dll',   'recv',          @recvCallback,          @recvNext) and
    HookAPI('wsock32.dll',   'ioctlsocket',   @ioctlsocketCallback,   @ioctlsocketNext) and
    HookAPI('wsock32.dll',   'closesocket',   @closesocketCallback,   @closesocketNext) and
    HookAPI('wsock32.dll',   'gethostbyname', @gethostbynameCallback, @gethostbynameNext) and
    HookAPI('wsock32.dll',   'WSAAsyncSelect',@WSAAsyncSelectCallback,@WSAAsyncSelectNext);

  if not Initialized then
  begin
    MessageBox(0, 
      'Ack, wkPackets initialization error!'#13#10+
      #13#10+
      'The packets processing library failed to initialize.'#13#10+
      'This could be caused by several reasons...'#13#10+
      'If you''re running an anti-virus program, it might be blocking wkPackets.'#13#10+
      'It''s possible that you need to be a system administrator to run wkPackets.'#13#10+
      'Maybe there''s some other software incompatibility with wkPackets...'#13#10+
      'The exact cause can''t be determined.'#13#10+
      'Anyway, try rebooting, disabling your security programs,'#13#10+
      'and if nothing works, post on the Team17 forums or contact CyberShadow.', 'Error', MB_ICONERROR);
    Exit;
  end;

  SetAffinity;
end.

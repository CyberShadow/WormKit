library wkWormNAT2;

{$IMAGEBASE $5a800000}

uses 
  ShareMem, 
  Windows, WinSock, SysUtils,
  Utils,
  madCHook;

const
  ProxyAddress = 'proxy.worms2d.info';
  ControlPort = 17018;
  PortError = $FFFF;

var
  GamePort: Word;

// ***************************************************************

procedure ConnectionThreadProc(ProxyPort: Integer); stdcall;
var
  ProxySocket, GameSocket: TSocket;
  ProxyAddr, GameAddr: TSockAddrIn;
  ProxyHost: PHostEnt;
  Bytes: u_long;
  ReadSet: record
    count: u_int;
    Socket: TSocket;
    end;
  TimeVal: TTimeVal;
  Buffer: array[0..4095] of Byte;
begin
  ProxySocket := socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );

  ProxyAddr.sin_family := AF_INET;
  ProxyHost := gethostbyname(PChar(ProxyAddress));
  if ProxyHost=nil then
  begin
    Log('[Proxy] Failed to resolve '+ProxyAddress+' (Error '+IntToStr(WSAGetLastError)+').');
    Exit;
  end;
  ProxyAddr.sin_addr.s_addr := PInAddr(ProxyHost.h_addr_list^).s_addr;
  ProxyAddr.sin_port := htons( ProxyPort );

  Log('[Proxy] Connecting to '+ProxyAddress+':'+IntToStr(ProxyPort));
  //DisableHooks;
  if connect( ProxySocket, ProxyAddr, sizeof(ProxyAddr) )=SOCKET_ERROR then
  begin
    Log('[Proxy] Failed to connect (Error '+IntToStr(WSAGetLastError)+').');
    //ReEnableHooks;
    Exit;
  end;

  GameSocket := socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );

  GameAddr.sin_family := AF_INET;
  GameAddr.sin_addr.s_addr := inet_addr('127.0.0.1');
  GameAddr.sin_port := htons( GamePort );

  Log('[Game] Connecting to localhost:'+IntToStr(GamePort));
  if connect( GameSocket, GameAddr, sizeof(GameAddr) )=SOCKET_ERROR then
  begin
    Log('[Game] Failed to connect (Error '+IntToStr(WSAGetLastError)+').');
    //ReEnableHooks;
    Exit;
  end;
  //ReEnableHooks;

  TimeVal.tv_sec:=0;
  TimeVal.tv_usec:=5000;

  repeat
    ReadSet.count:=1;
    ReadSet.Socket:=ProxySocket;
    if select(0, @ReadSet, nil, nil, @TimeVal)=SOCKET_ERROR then
    begin
      Log('[Proxy] Failed to select (Error '+IntToStr(WSAGetLastError)+')');
      Break;
    end;

    if ReadSet.count>0 then
    begin
      Bytes := 0;
      if ioctlsocket(ProxySocket, FIONREAD, Bytes)=SOCKET_ERROR then
      begin
        Log('[Proxy] Failed to ioctlsocket (Error '+IntToStr(WSAGetLastError)+').');
        break;
      end;
      
      if Bytes=0 then
      begin
        Log('[Proxy] Connection terminated (Error '+IntToStr(WSAGetLastError)+').');
        break;
      end;
      
      if Bytes>SizeOf(Buffer) then Bytes:=SizeOf(Buffer);
      if recv(ProxySocket, Buffer, Bytes, 0) <> Bytes then
      begin
        Log('[Proxy] Failed to read data (Error '+IntToStr(WSAGetLastError)+').');
        break;
      end;

      if send(GameSocket, Buffer, Bytes, 0) <> Bytes then
      begin
        Log('[Proxy] Failed to forward data (Error '+IntToStr(WSAGetLastError)+').');
        break;
      end;
    end;

    ReadSet.count:=1;
    ReadSet.Socket:=GameSocket;
    if select(0, @ReadSet, nil, nil, @TimeVal)=SOCKET_ERROR then
    begin
      Log('[Game] Failed to select (Error '+IntToStr(WSAGetLastError)+')');
      Break;
    end;

    if ReadSet.count>0 then
    begin
      Bytes := 0;
      if ioctlsocket(GameSocket, FIONREAD, Bytes)=SOCKET_ERROR then
      begin
        Log('[Game] Failed to ioctlsocket (Error '+IntToStr(WSAGetLastError)+').');
        break;
      end;
      
      if Bytes=0 then
      begin
        Log('[Game] Connection terminated (Error '+IntToStr(WSAGetLastError)+').');
        break;
      end;
      
      if Bytes>SizeOf(Buffer) then Bytes:=SizeOf(Buffer);
      if recv(GameSocket, Buffer, Bytes, 0) <> Bytes then
      begin
        Log('[Game] Failed to read data (Error '+IntToStr(WSAGetLastError)+').');
        break;
      end;

      if send(ProxySocket, Buffer, Bytes, 0) <> Bytes then
      begin
        Log('[Game] Failed to forward data (Error '+IntToStr(WSAGetLastError)+').');
        break;
      end;
    end;
  until False;
  closesocket(ProxySocket);
  closesocket(GameSocket);
end;


// ***************************************************************

var
  ExternalPort: Word = 0;
  Stopping: Boolean = False;

procedure ControlThreadProc(Foo: Pointer); stdcall;
var
  ControlSocket: TSocket;
  ControlAddr: TSockAddrIn;
  ControlHost: PHostEnt;
  Input: Word;
  Bytes: u_long;
  ThreadID: Cardinal;
  ReadSet: record
    count: u_int;
    Socket: TSocket;
    end;
  TimeVal: TTimeVal;
begin
  ControlSocket := socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );

  ControlAddr.sin_family := AF_INET;
  ControlHost := gethostbyname(PChar(ProxyAddress));
  if ControlHost=nil then
  begin
    Log('[Control] Failed to resolve '+ProxyAddress+' (Error '+IntToStr(WSAGetLastError)+').');
    ExternalPort := PortError;
    Exit;
  end;
  ControlAddr.sin_addr.s_addr := PInAddr(ControlHost.h_addr_list^).s_addr;
  ControlAddr.sin_port := htons( ControlPort );

  //DisableHooks;
  if connect( ControlSocket, ControlAddr, sizeof(ControlAddr) )=SOCKET_ERROR then
  begin
    Log('[Control] Failed to connect (Error '+IntToStr(WSAGetLastError)+').');
    //ReEnableHooks;
    ExternalPort := PortError;
    Exit;
  end;
  //ReEnableHooks;

  if recv( ControlSocket, Input, 2, 0 ) <> 2 then
  begin
    Log('[Control] Failed to read initial port (Error '+IntToStr(WSAGetLastError)+').');
    ExternalPort := PortError;
    closesocket(ControlSocket);
    Exit;
  end;
  ExternalPort := Input;
  Log('[Control] Hosting port: '+IntToStr(Input));

  TimeVal.tv_sec:=0;
  TimeVal.tv_usec:=5000;

  repeat
    ReadSet.count:=1;
    ReadSet.Socket:=ControlSocket;
    if select(0, @ReadSet, nil, nil, @TimeVal)=SOCKET_ERROR then
    begin
      Log('[Control] Failed to select (Error '+IntToStr(WSAGetLastError)+')');
      Break;
    end;

    if ReadSet.count>0 then
    begin
      Bytes := 0;
      if ioctlsocket(ControlSocket, FIONREAD, Bytes)=SOCKET_ERROR then
      begin
        Log('[Control] Failed to ioctlsocket (Error '+IntToStr(WSAGetLastError)+').');
        break;
      end;
      
      if Bytes=0 then
      begin
        Log('[Control] Connection terminated (Error '+IntToStr(WSAGetLastError)+').');
        break;
      end;
      
      if Bytes>=2 then
      begin
        if recv(ControlSocket, Input, 2, 0) <> 2 then
        begin
          Log('[Control] Failed to read next port (Error '+IntToStr(WSAGetLastError)+').');
          break;
        end;
        Log('[Control] New connection on port '+IntToStr(Input));
        CloseHandle(CreateThread(nil, 0, @ConnectionThreadProc, Pointer(Input), 0, ThreadID));
      end;
    end;
  until Stopping;
  ExternalPort := 0;
  Stopping := False;
  closesocket(ControlSocket);
end;

procedure StartControl;
var 
  ThreadID: Cardinal;
begin
  Stopping := True; while (ExternalPort<>0) and (ExternalPort<>PortError) do Sleep(5);
  ExternalPort := 0;
  Stopping := False;
  Sleep(50);
  CloseHandle(CreateThread(nil, 0, @ControlThreadProc, nil, 0, ThreadID));
  while ExternalPort=0 do Sleep(5);
end;

procedure StopControl;
begin
  Stopping := True;
end;

// ***************************************************************

var
  connectNext : function (s: TSocket; name: PSockAddrIn; NameLen: Integer) : Integer;  stdcall;
  closesocketNext : function(s: TSocket): Integer; stdcall;
  sendNext : function (s: TSocket; var Buf; len, flags: Integer): Integer; stdcall;

// connection parameters
var
  CurrentHTTPConnection: TSocket;
  HttpRequest: String;
  MyRealHost, NewHost: String;

function connectCallback(s: TSocket; name: PSockAddrIn; NameLen: Integer) : Integer; stdcall;
begin
  Result := connectNext(s, name, NameLen);
  if ntohs(name.sin_port)=80 then
    CurrentHTTPConnection := s;
end;

function closesocketCallback(s: TSocket): Integer; stdcall;
begin
  Result := closesocketNext(s);
  if s = CurrentHTTPConnection then
    CurrentHTTPConnection := 0;
end;

function ProcessHTTPRequest(var Data: string): Boolean;
var 
  P: Integer;
begin
  Result:=True;
  Log('[WWW] > '+Data);
  // process Data
  if Copy(Data, 1, 4)='GET ' then
    try
      // GET Http://wormnet1.team17.com:80/wormageddonweb/Game.asp?Cmd=Create&Name=ßCyberShadow-MD&HostIP=http://wormnat.xeon.cc/&Nick=CyberShadow-MD&Chan=AnythingGoes&Loc=40&Type=0 HTTP/1.0
      if (Pos('/Game.asp?Cmd=Create&', Data)<>0) and (Pos('HostIP=', Data)<>0) then
      begin
        P:=Pos('HostIP=', Data) + 7;
        MyRealHost:=Data; Delete(MyRealHost, 1, P-1); MyRealHost:=Copy(MyRealHost, 1, Pos('&', MyRealHost)-1);
        Delete(Data, P, Length(MyRealHost));

        GamePort := 17011;
        if Pos(':', MyRealHost)<>0 then
          GamePort := StrToIntDef(Copy(MyRealHost, Pos(':', MyRealHost)+1, 100), 17011);

        StartControl;
        if ExternalPort=PortError then
          Exit;

        NewHost := ProxyAddress + ':' + IntToStr(ExternalPort);
        Insert(NewHost, Data, P);
        Log('Game creation: '+MyRealHost+' substituted with '+NewHost);
      end;
      // GET Http://wormnet1.team17.com:80/wormageddonweb/Game.asp?Cmd=Close&GameID=1196270&Name=-CyberShadow-MD&HostID=&GuestID=&GameType=0 HTTP/1.0
      if (Pos('/Game.asp?Cmd=Close&', Data)<>0) and (Pos('HostIP=', Data)<>0) then 
      begin
        P:=Pos('HostIP=', Data) + 7;
        MyRealHost:=Data; Delete(MyRealHost, 1, P-1); MyRealHost:=Copy(MyRealHost, 1, Pos('&', MyRealHost)-1);
        Delete(Data, P, Length(MyRealHost));
        Insert(NewHost, Data, P);
        Log('Game close: '+MyRealHost+' substituted with '+NewHost);
        StopControl;
      end;
    except
      on E: Exception do
      begin
        Log('[HTTP] Error in processing GET request: '+E.Message);
        Exit;
      end;
    end;
end;

function sendCallback(s: TSocket; var Buf; len, flags: Integer): Integer; stdcall;
var
  Data: string;
begin
  if s = CurrentHTTPConnection then
  begin
    SetLength(Data, len);
    Move(Buf, Data[1], len);
    HttpRequest := HttpRequest + Data;
    if Pos(#13#10#13#10, HttpRequest) > 0 then
    begin
      ProcessHTTPRequest(HttpRequest);
      Result := sendNext(s, HttpRequest[1], Length(HttpRequest), flags);
      if Result<>Length(HttpRequest) then
        Log('Bad send result!');
      HttpRequest := '';
    end;
    Result := len;
  end
  else
    Result := sendNext(s, Buf, len, flags);
end;

// ***************************************************************

begin
  if FileExists('wkWormNAT.dll') then
  begin
    MessageBox(0, 
      'Ack! You seem to have the old WormNAT installed.'#13#10+
      #13#10+
      'Please delete wkWormNAT.dll. The first version of'#13#10+
      'WormNAT is obsolete and incompatible with WormNAT2.'#13#10+
      'WormNAT2 will not work until you do that.', 'Error', MB_ICONERROR);
    ExitProcess(1);
  end;

  if FileExists('wkPackets.dll') then
  begin
    MessageBox(0, 
      'Ack! You seem to have wkPackets installed.'#13#10+
      #13#10+
      'Please delete wkPackets.dll. Unfortunately, it is known'#13#10+
      'to cause "skipped packet" errors. WormNAT2 no longer requires.'#13#10+
      'wkPackets to run.', 'Error', MB_ICONERROR);
    ExitProcess(1);
  end;

{$IFNDEF NOPOPUP}
  MessageBox(0, 
    '                     Greetings WormNAT2 user!'#13#10+
    #13#10+
    'This is a reminder message to remind you that WormNAT2        '#13#10+
    'is a free service. Using WormNAT2 tunnels all data'#13#10+
    'through a proxy server hosted by the community, thus'#13#10+
    'consuming bandwidth and other resources. Therefore,'#13#10+
    'we''d like to ask you to only use WormNAT2 when you'#13#10+
    'have already tried configuring hosting the proper way.'#13#10+
    #13#10+
    'Don''t forget that you can find instructions on how'#13#10+
    'to set up hosting here:'#13#10+
    #13#10+
    '                  http://worms2d.info/Hosting',
    'A friendly reminder', MB_ICONINFORMATION);
{$ENDIF}
  
  Log('----------------------------------------');
  HookAPI('wsock32.dll', 'connect', @connectCallback, @connectNext);
  HookAPI('wsock32.dll', 'closesocket', @closesocketCallback, @closesocketNext);
  HookAPI('wsock32.dll', 'send', @sendCallback, @sendNext);
end.

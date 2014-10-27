library wkWormNAT2;

{$IMAGEBASE $5a800000}

uses 
  Windows, WinSock, Types,
  USysUtils in '..\LiteUnits\USysUtils.pas',
  MyStrUtils in '..\MyStrUtils\MyStrUtils.pas',
  Utils,
  madCHook;

const
  ProxyAddress = 'proxy.worms2d.info';
  ControlPort = 17018;
  PortError = $FFFF;
  PortUnknown = 1; // WormNAT2Ex mode

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
  ExternalSocket: Boolean = False;
  ExternalPort: Word = 0;
  Stopping: Boolean = False;
  ControlSocket: TSocket;

procedure ControlThreadProc(Foo: Pointer); stdcall;
var
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
  if ExternalSocket then
  begin
    Log('Control socket is external, skipping handshake.');
    ExternalPort := PortUnknown;
  end
  else
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
  end;

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

procedure StartControl(ControlWait: boolean = false);
var
  ThreadID: Cardinal;
begin
  Stopping := True; while (ExternalPort<>0) and (ExternalPort<>PortError) do Sleep(5);
  ExternalPort := 0;
  Stopping := False;
  Sleep(50);
  CloseHandle(CreateThread(nil, 0, @ControlThreadProc, nil, 0, ThreadID));
  if ControlWait then while ExternalPort=0 do Sleep(5);
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
    begin
      // GET Http://wormnet1.team17.com:80/wormageddonweb/Game.asp?Cmd=Create&Name=ßCyberShadow-MD&HostIP=http://wormnat.xeon.cc/&Nick=CyberShadow-MD&Chan=AnythingGoes&Loc=40&Type=0 HTTP/1.0
      if (Pos('/Game.asp?Cmd=Create&', Data)<>0) and (Pos('HostIP=', Data)<>0) then
      begin
        P:=Pos('HostIP=', Data) + 7;
        MyRealHost:=Data; Delete(MyRealHost, 1, P-1); MyRealHost:=Copy(MyRealHost, 1, Pos('&', MyRealHost)-1);
        Delete(Data, P, Length(MyRealHost));

        GamePort := 17011;
        if Pos(':', MyRealHost)<>0 then
          GamePort := StrToIntDef(Copy(MyRealHost, Pos(':', MyRealHost)+1, 100), 17011);

        StartControl(true);
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

procedure CheckCommandLine;
var
  I: Integer;
  Arr: TStringDynArray;
  wsaData: TWSAData;
  ProcessHandle, Event: THandle;
begin
  for I:=1 to ParamCount-1 do
    if ParamStr(I)='/wnat2' then
    begin
      Arr := Split(ParamStr(I+1), '-');
      if Length(Arr)<>3 then
        continue;

      ExternalSocket := true;

      if WSAStartup(MAKEWORD(2, 2), wsaData)=0 then
      begin
        ProcessHandle := OpenProcess(PROCESS_ALL_ACCESS, FALSE, StrToInt(Arr[0]));
        DuplicateHandle(ProcessHandle, THandle(StrToInt(Arr[1])), GetCurrentProcess(), @ControlSocket, 0, FALSE, DUPLICATE_SAME_ACCESS or DUPLICATE_CLOSE_SOURCE);
        DuplicateHandle(ProcessHandle, THandle(StrToInt(Arr[2])), GetCurrentProcess(), @Event        , 0, FALSE, DUPLICATE_SAME_ACCESS);
        CloseHandle(ProcessHandle);
        Log('New socket: ' + IntToStr(ControlSocket));

        if Event<>0 then
        begin
          if  not SetEvent(Event) then
            Log('SetEvent failed.');
          CloseHandle(Event);
        end;

        if ControlSocket<>0 then
          StartControl(false)
          //No wait because this code part doesn't need it
          //and the DLL is not yet ready to start threads
        else
          Log('Socket dupe failed.');
      end
      else
        Log('WSAStartup failed.');
    end;
end;

// ***************************************************************

begin
  if FileExists('wkWormNAT.dll') then
  begin
    MessageBox(0, 
      'Ack! You seem to have the old WormNAT installed.'#13#10+
      #13#10+
      'Please delete wkWormNAT.dll. The first version of '+
      'WormNAT is obsolete and incompatible with WormNAT2.'#13#10+
      'WormNAT2 will not work until you do that.', 'Error', MB_ICONERROR);
    ExitProcess(1);
  end;

{$IFNDEF ALLOW_WKPACKETS}
  if FileExists('wkPackets.dll') then
  begin
    MessageBox(0, 
      'Ack! You seem to have wkPackets installed.'#13#10+
      #13#10+
      'Please delete wkPackets.dll. Unfortunately, it is known '+
      'to cause "skipped packet" errors. WormNAT2 no longer requires '+
      'wkPackets to run.', 'Error', MB_ICONERROR);
    ExitProcess(1);
  end;
{$ENDIF}

{$IFNDEF NOPOPUP}
  MessageBox(0, 
    '                     Greetings WormNAT2 user!'#13#10+
    #13#10+
    'This is a reminder message to remind you that WormNAT2 '+
    'is a free service. Using WormNAT2 tunnels all data '+
    'through a proxy server hosted by the community, thus '+
    'consuming bandwidth and other resources. Therefore, '+
    'we''d like to ask you to only use WormNAT2 when you '+
    'have already tried configuring hosting the proper way.'#13#10+
    #13#10+
    'Don''t forget that you can find instructions on how '+
    'to set up hosting here:'#13#10+
    #13#10+
    '                  http://worms2d.info/Hosting',
    'A friendly reminder', MB_ICONINFORMATION);
{$ENDIF}

  if not (
    HookAPI('wsock32.dll', 'connect', @connectCallback, @connectNext) and
    HookAPI('wsock32.dll', 'closesocket', @closesocketCallback, @closesocketNext) and
    HookAPI('wsock32.dll', 'send', @sendCallback, @sendNext)) then
  begin
    MessageBox(0,
      'Ack, wkWormNAT2 initialization error!'#13#10+
      #13#10+
      'wkWormNAT2 failed to install the network API hooks it needs in order to work.'#13#10+
      'This could be caused by several reasons...'#13#10+
      'If you''re running an anti-virus program, it might be blocking wkWormNAT2.'#13#10+
      'It''s possible that you need to be a system administrator to run wkWormNAT2.'#13#10+
      'Maybe there''s some other software incompatibility with wkWormNAT2...'#13#10+
      'The exact cause can''t be determined.'#13#10+
      'Anyway, try rebooting and disabling your security programs.', 'Error', MB_ICONERROR);
    ExitProcess(1);
  end;

  Log('----------------------------------------');

  CheckCommandLine;
end.

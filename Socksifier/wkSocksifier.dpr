library wkSocksifier;

{$IMAGEBASE $65800000}

uses Windows, USysUtils, WinSock, madCodeHook, IniFiles;

// ***************************************************************

var
  SOCKSServer: string;
  SOCKSPort: Integer;
  RoutePorts: string;
 
procedure LoadConfig;
var
  Config: TMemIniFile;
begin
  Config := TMemIniFile.Create(ExtractFilePath(ParamStr(0))+'Socksifier.ini');
  SOCKSServer    :=Config.ReadString ('SOCKS',    'Server',        ''); 
  SOCKSPort      :=Config.ReadInteger('SOCKS',    'Port',          0);
  RoutePorts     :=Config.ReadString ('SOCKS',    'RoutePorts',    '');
  Config.Free;
end;

// ***************************************************************

var 
  connectNext : function (s: TSocket; name: PSockAddrIn; NameLen: Integer) : Integer;  stdcall;
  WSAAsyncSelectNext : function (s: TSocket; HWindow: HWND; wMsg: u_int; lEvent: Longint): Integer; stdcall;
  AsyncMessageWindow: hWnd;
  AsyncMessage: Integer;
  AsyncEvents: Integer;

// ***************************************************************

type
  TSocksPacket=packed record
    Version, Command: Byte;
    Port: Word;
    IP: TInAddr;
    Null: Byte;
    end;

function connectCallback(s: TSocket; name: PSockAddrIn; NameLen: Integer) : Integer;  stdcall;
var
  SOCKSAddr: TSockAddrIn;
  Packet: TSocksPacket;
  Mode: Integer;
begin
  // ntohs(name.sin_port) | inet_ntoa(name.sin_addr)
  if Pos(','+IntToStr(ntohs(name.sin_port))+',', ','+RoutePorts+',')=0 then
    begin
    Result:=connectNext(s, name, NameLen);
    Exit;
    end;

  if WSAAsyncSelectNext(s, AsyncMessageWindow, 0, 0)=SOCKET_ERROR then
    begin
    MessageBox(0, PChar('0: '+IntToStr(WSAGetLastError)), nil, 0);
    Result:=SOCKET_ERROR;
    Exit;
    end;
  Mode:=0;
  if ioctlsocket(s, FIONBIO, Mode)=SOCKET_ERROR then
    begin
    MessageBox(0, PChar('1: '+IntToStr(WSAGetLastError)), nil, 0);
    Result:=SOCKET_ERROR;
    Exit;
    end;

  SOCKSAddr.sin_family := AF_INET;
  SOCKSAddr.sin_addr.s_addr := inet_addr(PChar(SOCKSServer));
  SOCKSAddr.sin_port := htons( SOCKSPort );
  Result:=connectNext(s, @SOCKSAddr, SizeOf(SOCKSAddr));
  if Result=SOCKET_ERROR then
    begin
    MessageBox(0, PChar('2: '+IntToStr(WSAGetLastError)+#13#10+inet_ntoa(SOCKSAddr.sin_addr)+#13#10+SOCKSServer), nil, 0);
    Exit;
    end;

  Packet.Version:=4;
  Packet.Command:=1;  // CONNECT
  Packet.Port:=name.sin_port;
  Packet.IP.s_addr:=name.sin_addr.s_addr;
  Packet.Null:=0;
  send(s, Packet, SizeOf(Packet)  , 0);
  recv(s, Packet, SizeOf(Packet)-1, 0);
  if Packet.Command<>90 then 
    begin
    closesocket(s);
    Result:=SOCKET_ERROR;  WSASetLastError(WSAEACCES);
    Exit;
    end;

  WSAAsyncSelectNext(s, AsyncMessageWindow, AsyncMessage, AsyncEvents);
  PostMessage(AsyncMessageWindow, AsyncMessage, s, FD_CONNECT);
  WSASetLastError(WSAEWOULDBLOCK);
  Result:=SOCKET_ERROR;
end;


function WSAAsyncSelectCallback (s: TSocket; HWindow: HWND; wMsg: u_int; lEvent: Longint): Integer; stdcall;
begin
  AsyncMessageWindow:=HWindow;
  AsyncMessage:=wMsg;
  AsyncEvents:=lEvent;
  Result:=WSAAsyncSelectNext(s, HWindow, wMsg, lEvent);
end;
// ***************************************************************

begin
  if not FileExists('Socksifier.ini') then
    begin
    MessageBox(0, 'Warning: Socksifier.ini not found.'#13#10#13#10+
               'Socksifier reads its settings from Socksifier.ini. '#13#10+
               'Chances are that you didn''t copy over this file from the WormKitModules\Socksifier subfolder.'#13#10+
               'Socksifier will be disabled for this session.', 'Socksifier', MB_ICONWARNING);
    Exit;
    end;
  LoadConfig;
  HookAPI('wsock32.dll',   'connect',       @connectCallback,       @connectNext);
  HookAPI('wsock32.dll',   'WSAAsyncSelect',@WSAAsyncSelectCallback,@WSAAsyncSelectNext);
end.

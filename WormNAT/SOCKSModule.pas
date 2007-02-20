unit SOCKSModule;  // SOCKS back-end module for WormNAT

// SOCKS dox: http://www.smartftp.com/Products/SmartFTP/RFC/socks4.protocol

interface
uses
  Base, Windows, Classes, SysUtils, WinSock, Data, IniFiles;

// options
var
  SOCKSServer: string;
  SOCKSPort: Integer;
  SOCKSBoundPort: Integer;

procedure LoadConfig(F: TCustomIniFile);
  
type
  TSOCKSMode = (imServer, imClient);

  TSOCKSLink = class (TThread)   // link for each connection via the proxy server
    Link: TLink;    // the Worms link
    SOCKSSocket: TSocket;
    InitMode: TSOCKSMode;
    Queue: string;
    procedure Execute; override;
    end;

  TSOCKSModule = class (TModule)
    SOCKSLinks: array of TSOCKSLink;
    constructor Create; override;
    procedure Main; override;
    function PerUserConfig(IP, NickName: string): string; override;
    procedure ReverseConnect(ALink: TLink);
    procedure Write(From: TLink; S: string); override;
    procedure OnDisconnect(From: TLink); override;
    function FindSOCKSLink(By: TLink): TSOCKSLink;
    function AddLink(APlayer: string; ASocket: TSocket): TLink; override;
    function AddSOCKSLink(ALink: TLink; ASOCKSSocket: TSocket; AMode: TSOCKSMode): TSOCKSLink; 
    end;

function CheckProxy(Target: PChar): Boolean; stdcall; external 'SocksFinder.dll';

implementation

procedure LoadConfig(F: TCustomIniFile);
begin
  SOCKSServer    :=F.ReadString ('SOCKS',    'Server',        ''); 
  SOCKSPort      :=F.ReadInteger('SOCKS',    'Port',          0);
  SOCKSBoundPort :=F.ReadInteger('SOCKS',    'BoundPort',     0);
end;

constructor TSOCKSModule.Create;
begin
  inherited;
  SetLength(SOCKSLinks, 0);
end;

procedure TSOCKSModule.Main;
begin
  if not CheckProxy(PChar(SOCKSServer+':'+IntToStr(SOCKSPort))) then
    raise Exception.Create('[SOCKS] Can''t connect to the SOCKS proxy, please re-run the autoconfiguration.');

  Ready:=True;
  Log('[SOCKS] Ready.');
  
  repeat
    Sleep(10);
  until Stop;

  Log('[SOCKS] Stopping.');
  Finished:=True;
end;

type
  TSocksPacket=record
    Version, Command: Byte;
    Port: Word;
    IP: TInAddr;
    end;

function TSOCKSModule.PerUserConfig(IP, Nickname: string): string; 
var
  SOCKSAddr, WormsAddr: TSockAddrIn;
  SOCKSHost: PHostEnt;
  WormsSocket, SOCKSSocket: TSocket;
  Packet: TSocksPacket;
  R: Integer;
  WormsLink: TLink;
  OK: Boolean; Delay: Integer;
begin
  // some user wants to connect to our Worms server; we need to configure 
  // the SOCKS to expect an inbound connection and route it through us, 
  // then tell the user the bound port for the proxy server
  
  Result:='';

  Delay:=1000; OK:=False;
  repeat
    Log('[SOCKS] Connecting to '+SOCKSServer+':'+IntToStr(SOCKSPort)+'...');

    NoCapture := True;
    SOCKSSocket := socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );

    SOCKSAddr.sin_family := AF_INET;
    SOCKSHost:=gethostbyname(PChar(SOCKSServer));  
    if SOCKSHost=nil then
      begin
      Log('[SOCKS] Failed to resolve '+SOCKSServer+' (Error '+IntToStr(WSAGetLastError)+').');
      NoCapture := False;
      Exit;
      end;
    SOCKSAddr.sin_addr.s_addr := PInAddr(SOCKSHost.h_addr_list^).s_addr;
    SOCKSAddr.sin_port := htons( SOCKSPort );

    if connect( SOCKSSocket, SOCKSAddr, sizeof(SOCKSAddr) )=SOCKET_ERROR then
      begin
      Log('[SOCKS] Failed to connect (Error '+IntToStr(WSAGetLastError)+').');
      NoCapture:=False;
      if Delay>60000 then
        Exit;
      Sleep(Delay); Delay:=Delay*2; Continue;
      end;
    NoCapture := False;
    OK:=True;
  until OK;

  Packet.Version:=4;
  Packet.Command:=2;  // BIND
  Packet.Port:=0;
  Packet.IP.S_addr:=inet_addr(PChar(IP));
  send(SOCKSSocket, Packet, SizeOf(Packet), 0);
  //if Terminated then Exit;

  R:=recv(SOCKSSocket, Packet, SizeOf(Packet), 0);
  if R=0 then
    begin
    Log('[SOCKS] Error while receiving reply ('+IntToStr(WSAGetLastError)+').');
    closesocket(SOCKSSocket);
    Exit;
    end;
  //if Terminated then Exit;

  if Packet.Command=90 then 
    Log('[SOCKS] Received reply : Request granted ('+inet_ntoa(Packet.IP)+':'+IntToStr(Packet.Port)+')')
  else
    begin
    Log('[SOCKS] Received bad reply ('+IntToStr(Packet.Command)+').');
    closesocket(SOCKSSocket);
    Exit;
    end;

  // send the client the port to connect to via the IRC Lingering
  Result:='BoundPort='+IntToStr(Packet.Port)+#13#10;

  // now open a connection to Worms
  NoCapture := True;
  WormsSocket := socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );

  WormsAddr.sin_family := AF_INET;
  WormsAddr.sin_addr.s_addr := inet_addr('127.0.0.1');
  WormsAddr.sin_port := htons( 17011 );

  if connect( WormsSocket, WormsAddr, sizeof(WormsAddr) )=SOCKET_ERROR then
    begin
    Log('[SOCKS] Failed to connect Link to Worms (Error '+IntToStr(WSAGetLastError)+').');
    NoCapture := False;
    closesocket(SOCKSSocket);
    Exit;
    end;
  NoCapture := False;
  
  WormsLink:=AddLink(Nickname, WormsSocket);

  AddSOCKSLink(WormsLink, SOCKSSocket, imServer);
end;

procedure TSOCKSModule.ReverseConnect(ALink: TLink);
var
  SOCKSAddr: TSockAddrIn;
  SOCKSHost: PHostEnt;
  SOCKSSocket: TSocket;
  OK: Boolean; Delay: Integer;
begin
  // we are the client, and we're connecting to the bound IP/Port sent to us from the server via the Lingering
  
  Delay:=1000; OK:=False;
  repeat
    Log('[SOCKS] Connecting to bound address '+SOCKSServer+':'+IntToStr(SOCKSBoundPort)+'...');

    NoCapture := True;
    SOCKSSocket := socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );

    SOCKSAddr.sin_family := AF_INET;
    SOCKSHost:=gethostbyname(PChar(SOCKSServer));  
    if SOCKSHost=nil then
      begin
      Log('[SOCKS] Failed to resolve '+SOCKSServer+' (Error '+IntToStr(WSAGetLastError)+').');
      NoCapture := False;
      Exit;
      end;
    SOCKSAddr.sin_addr.s_addr := PInAddr(SOCKSHost.h_addr_list^).s_addr;
    SOCKSAddr.sin_port := htons( SOCKSBoundPort );

    if connect( SOCKSSocket, SOCKSAddr, sizeof(SOCKSAddr) )=SOCKET_ERROR then
      begin
      Log('[SOCKS] Failed to connect (Error '+IntToStr(WSAGetLastError)+').');
      NoCapture:=False;
      if Delay>60000 then
        Exit;
      Sleep(Delay); Delay:=Delay*2; Continue;
      end;
    NoCapture := False;
    OK:=True;
  until OK;

  Log('[SOCKS] Connected, creating SOCKS link.');

  // start the independent thread
  AddSOCKSLink(ALink, SOCKSSocket, imClient);
end;

// Worms -> WormNAT -> SOCKS
procedure TSOCKSModule.Write(From: TLink; S: string); 
begin
  with FindSOCKSLink(From) do
    Queue:=Queue+S;
  Log(' [SOCKS] Forwarded '+IntToStr(Length(S))+' bytes.', 2);
end;

// the Worms <-> WormNAT link failed
procedure TSOCKSModule.OnDisconnect(From: TLink); 
begin
  with FindSOCKSLink(From) do
   if SOCKSSocket<>0 then
    begin
    closesocket(SOCKSSocket);
    SOCKSSocket:=0;
    Terminate;
    end;
end;

// this will also be called by the Listener (when Worms is trying an outbound connection)
function TSOCKSModule.AddLink(APlayer: string; ASocket: TSocket): TLink; 
begin
  Result:=inherited AddLink(APlayer, ASocket);
  if SOCKSBoundPort=0 then
    begin  
    { obsolete behaviour
    Log('[SOCKS] Unexpected outbound connection attempt, no bound port configured!');
    closesocket(ASocket);
    Result.Socket:=0;
    Exit}

    // we are the server
    // do nothing, this is called from TSOCKSModule.PerUserConfig
    Log('[SOCKS] Adding Worms link of type Server->Client', 2);
    end
  else
    begin
    // we are the client, Listener caught this connection
    Log('[SOCKS] Adding Worms link of type Client->Server', 2);
    ReverseConnect(Result);
    end;
end;

function TSOCKSModule.AddSOCKSLink(ALink: TLink; ASOCKSSocket: TSocket; AMode: TSOCKSMode): TSOCKSLink;
begin
  Result:=TSOCKSLink.Create(True);
  Result.Link:=ALink;
  Result.SOCKSSocket:=ASOCKSSocket;
  Result.InitMode:=AMode;
  Log('[SOCKS] Adding SOCKS link: '+ALink.Nickname);
  SetLength(SOCKSLinks, Length(SOCKSLinks)+1);
  SOCKSLinks[Length(SOCKSLinks)-1]:=Result;
  Result.Resume;
end;

function TSOCKSModule.FindSOCKSLink(By: TLink): TSOCKSLink;
var
  I: Integer;
begin
  for I:=0 to Length(SOCKSLinks)-1 do
    if SOCKSLinks[I].Link=By then
      begin
      Result:=SOCKSLinks[I];
      Exit
      end;
  Log('[SOCKS] Failed to find SOCKSLink corresponding to '+By.Nickname);
  Result:=nil;
end;

// ***************************************************************

procedure TSOCKSLink.Execute;
var
  R: Integer;
  Packet: TSocksPacket;
  Bytes: u_long; 
  Data: string;
  ReadSet: record
    count: u_int;
    Socket: TSocket;
    end;
  TimeVal: TTimeVal;
begin
  if InitMode=imServer then
    begin
    R:=recv(SOCKSSocket, Packet, SizeOf(Packet), 0);
    if R=0 then
      begin
      Log('[SOCKSLINK] Error while receiving second reply ('+IntToStr(WSAGetLastError)+').');
      closesocket(SOCKSSocket); SOCKSSocket:=0;
      closesocket(Link.Socket); Link.Socket:=0;
      Exit;
      end;

    if Packet.Command=90 then 
      Log('[SOCKSLINK] Received second reply : All OK ('+inet_ntoa(Packet.IP)+':'+IntToStr(Packet.Port)+')')
    else
      begin
      Log('[SOCKSLINK] Received bad second reply ('+IntToStr(Packet.Command)+').');
      closesocket(Link.Socket); SOCKSSocket:=0;
      closesocket(SOCKSSocket); Link.Socket:=0;
      Exit;
      end;

    // some servers need 1 additional null byte to be sent via the data connection...
    //Term:=0;
    //send(SOCKSSocket, Term, 1, 0);  // ending NULL byte
    Log('[SOCKSLINK] Server-side link with '+Link.Nickname+' ready.');
    end
  else
    begin
    //recv(SOCKSSocket, Term, 1, 0);  // ending NULL byte
    Log('[SOCKSLINK] Client-side link with '+Link.Nickname+' ready.');
    end;

  repeat
    Link.CheckForData;

    while Queue<>'' do
      begin
      Bytes:=send(SOCKSSocket, Queue[1], Length(Queue), 0);
      if Bytes=0 then 
        begin
        SOCKSSocket:=0;
        Log('[SOCKSLINK] Link to '+Link.NickName+' closed gracefully.');
        Link.Owner.OnDisconnect(Link);
        Break;
        end;
      if Bytes=SOCKET_ERROR then 
        begin
        SOCKSSocket:=0;
        Log('[SOCKSLINK] Link to '+Link.NickName+' terminated with error '+IntToStr(WSAGetLastError));
        Link.Owner.OnDisconnect(Link);
        Break;
        end;
      Delete(Queue, 1, Bytes);
      Log(' [SOCKSLINK] Sent '+IntToStr(Bytes)+' bytes to the server.', 2);
      end;

    TimeVal.tv_sec:=0;
    TimeVal.tv_usec:=0;

    if SOCKSSocket<>0 then
     repeat
      ReadSet.count:=1;
      ReadSet.Socket:=SOCKSSocket;
      R:=select(0, @ReadSet, nil, nil, @TimeVal);
      if R=SOCKET_ERROR then
        begin
        SOCKSSocket:=0;
        Log('[SOCKSLINK] Link to '+Link.NickName+' terminated with error '+IntToStr(WSAGetLastError)+' in select()');
        closesocket(Link.Socket); Link.Socket:=0;
        Break;
        end;

      if (ReadSet.count=0)or(R=0) then
        Break;         // nothing to read

      R := ioctlsocket(SOCKSSocket, FIONREAD, Bytes);
      if R=SOCKET_ERROR then
        begin
        SOCKSSocket:=0;
        Log('[SOCKSLINK] Link to '+Link.NickName+' terminated with error '+IntToStr(WSAGetLastError));
        closesocket(Link.Socket); Link.Socket:=0;
        Break;
        end;
      
      if Bytes=0 then 
        begin
        SOCKSSocket:=0;
        Log('[SOCKSLINK] Link to '+Link.NickName+' closed gracefully.');
        closesocket(Link.Socket); Link.Socket:=0;
        Break;
        end;

      SetLength(Data, Bytes);
      Bytes := recv(SOCKSSocket, Data[1], Bytes, 0);
      if Bytes=0 then 
        begin
        SOCKSSocket:=0;
        Log('[SOCKSLINK] Link to '+Link.NickName+' closed gracefully.');
        closesocket(Link.Socket); Link.Socket:=0;
        Break;
        end;
      if Bytes=SOCKET_ERROR then 
        begin
        SOCKSSocket:=0;
        Log('[SOCKSLINK] Link to '+Link.NickName+' terminated with error '+IntToStr(WSAGetLastError));
        closesocket(Link.Socket); Link.Socket:=0;
        Break;
        end;
      SetLength(Data, Bytes);
      Link.Write(Data);
     until False;

    Sleep(10);
  until Link.Owner.Stop or Link.Owner.Finished or (SOCKSSocket=0);

  if SOCKSSocket<>0 then
    begin closesocket(SOCKSSocket); SOCKSSocket:=0; end;
  if Link.Socket<>0 then
    begin closesocket(Link.Socket); Link.Socket:=0; end;
end;

end.

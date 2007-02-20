unit MWNModule;  // MyWormNet Module: module for MyWormNet built-in WormNAT support
                 // almost identical to SOCKS

interface
uses
  Base, Windows, Classes, SysUtils, WinSock, Data, IniFiles;

// options
var
  MWNPort: Integer;

procedure LoadConfig(F: TCustomIniFile);
  
type
  TMWNLink = class (TThread)   // link for each connection via the proxy server
    Link: TLink;    // the Worms link
    MWNSocket: TSocket;
    Queue: string;
    procedure Execute; override;
    end;

  TMWNModule = class (TModule)
    MWNLinks: array of TMWNLink;
    constructor Create; override;
    procedure Main; override;
    function PerUserConfig(IP, NickName: string): string; override;
    procedure ReverseConnect(ALink: TLink);
    procedure Write(From: TLink; S: string); override;
    procedure OnDisconnect(From: TLink); override;
    function FindMWNLink(By: TLink): TMWNLink;
    function AddLink(APlayer: string; ASocket: TSocket): TLink; override;
    function AddMWNLink(ALink: TLink; AMWNSocket: TSocket): TMWNLink; 
    end;

implementation
uses
  LingerIRC;

procedure LoadConfig(F: TCustomIniFile);
begin
end;

constructor TMWNModule.Create;
begin
  inherited;
  SetLength(MWNLinks, 0);
end;

procedure TMWNModule.Main;
begin
  Ready:=True;
  Log('[MWN] Ready.');
  repeat
    Sleep(10);
  until Stop;
  Log('[MWN] Stopping.');
  Finished:=True;
end;

function TMWNModule.PerUserConfig(IP, Nickname: string): string; 
var
  MWNAddr, WormsAddr: TSockAddrIn;
  MWNHost: PHostEnt;
  WormsSocket, MWNSocket: TSocket;
  S: string;
  WormsLink: TLink;
  OK: Boolean; Delay: Integer;
begin
  // some user wants to connect to our Worms server; we need to configure 
  // the MWN to expect an inbound connection and route it through us, 
  // then tell the user the bound port for the proxy server
  
  S:='EXPECT '+Nickname+#13#10;
  send(LingeringIRC, S[1], Length(S), 0);

  Result:='';

  Delay:=1000; OK:=False;
  repeat
    Log('[MWN] Connecting to '+WormNetServer+':'+IntToStr(MWNPort)+'...');

    NoCapture := True;
    MWNSocket := socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );

    MWNAddr.sin_family := AF_INET;
    MWNHost:=gethostbyname(PChar(WormNetServer));  
    if MWNHost=nil then
      begin
      Log('[MWN] Failed to resolve '+WormNetServer+' (Error '+IntToStr(WSAGetLastError)+').');
      NoCapture := False;
      Exit;
      end;
    MWNAddr.sin_addr.s_addr := PInAddr(MWNHost.h_addr_list^).s_addr;
    MWNAddr.sin_port := htons( MWNPort );

    if connect( MWNSocket, MWNAddr, sizeof(MWNAddr) )=SOCKET_ERROR then
      begin
      Log('[MWN] Failed to connect (Error '+IntToStr(WSAGetLastError)+').');
      NoCapture:=False;
      if Delay>60000 then
        Exit;
      Sleep(Delay); Delay:=Delay*2; Continue;
      end;
    NoCapture := False;
    OK:=True;
  until OK;

  // now open a connection to Worms
  NoCapture := True;
  WormsSocket := socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );

  WormsAddr.sin_family := AF_INET;
  WormsAddr.sin_addr.s_addr := inet_addr('127.0.0.1');
  WormsAddr.sin_port := htons( 17011 );

  if connect( WormsSocket, WormsAddr, sizeof(WormsAddr) )=SOCKET_ERROR then
    begin
    Log('[MWN] Failed to connect Link to Worms (Error '+IntToStr(WSAGetLastError)+').');
    NoCapture := False;
    closesocket(MWNSocket);
    Exit;
    end;
  NoCapture := False;
  
  WormsLink:=AddLink(Nickname, WormsSocket);

  AddMWNLink(WormsLink, MWNSocket);
end;

procedure TMWNModule.ReverseConnect(ALink: TLink);
var
  MWNAddr: TSockAddrIn;
  MWNHost: PHostEnt;
  MWNSocket: TSocket;
  OK: Boolean; Delay: Integer;
begin
  // we are the client, and we're connecting to the bound IP/Port sent to us from the server via the Lingering
  
  Delay:=1000; OK:=False;
  repeat
    Log('[MWN] Connecting to MyWormNet '+WormNetServer+':'+IntToStr(MWNPort)+'...');

    NoCapture := True;
    MWNSocket := socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );

    MWNAddr.sin_family := AF_INET;
    MWNHost:=gethostbyname(PChar(WormNetServer));  
    if MWNHost=nil then
      begin
      Log('[MWN] Failed to resolve '+WormNetServer+' (Error '+IntToStr(WSAGetLastError)+').');
      NoCapture := False;
      Exit;
      end;
    MWNAddr.sin_addr.s_addr := PInAddr(MWNHost.h_addr_list^).s_addr;
    MWNAddr.sin_port := htons( MWNPort );

    if connect( MWNSocket, MWNAddr, sizeof(MWNAddr) )=SOCKET_ERROR then
      begin
      Log('[MWN] Failed to connect (Error '+IntToStr(WSAGetLastError)+').');
      NoCapture:=False;
      if Delay>60000 then
        Exit;
      Sleep(Delay); Delay:=Delay*2; Continue;
      end;
    NoCapture := False;
    OK:=True;
  until OK;

  Log('[MWN] Connected, creating MWN link.');

  // start the independent thread
  AddMWNLink(ALink, MWNSocket);
end;

// Worms -> WormNAT -> MyWormNet
procedure TMWNModule.Write(From: TLink; S: string); 
begin
  with FindMWNLink(From) do
    Queue:=Queue+S;
  Log(' [MWN] Forwarded '+IntToStr(Length(S))+' bytes.', 2);
end;

// the Worms <-> WormNAT link failed
procedure TMWNModule.OnDisconnect(From: TLink); 
begin
  with FindMWNLink(From) do
   if MWNSocket<>0 then
    begin
    closesocket(MWNSocket);
    MWNSocket:=0;
    Terminate;
    end;
end;

// this will also be called by the Listener (when Worms is trying an outbound connection)
function TMWNModule.AddLink(APlayer: string; ASocket: TSocket): TLink; 
begin
  Result:=inherited AddLink(APlayer, ASocket);
  if HostPlayer='' then
    begin  
    // we are the server
    // do nothing, this is called from TMWNModule.PerUserConfig
    Log('[MWN] Adding Worms link of type Server->Client', 2);
    end
  else
    begin
    // we are the client, Listener caught this connection
    Log('[MWN] Adding Worms link of type Client->Server', 2);
    ReverseConnect(Result);
    end;
end;

function TMWNModule.AddMWNLink(ALink: TLink; AMWNSocket: TSocket): TMWNLink;
begin
  Result:=TMWNLink.Create(True);
  Result.Link:=ALink;
  Result.MWNSocket:=AMWNSocket;
  Log('[MWN] Adding MWN link: '+ALink.Nickname);
  SetLength(MWNLinks, Length(MWNLinks)+1);
  MWNLinks[Length(MWNLinks)-1]:=Result;
  Result.Resume;
end;

function TMWNModule.FindMWNLink(By: TLink): TMWNLink;
var
  I: Integer;
begin
  for I:=0 to Length(MWNLinks)-1 do
    if MWNLinks[I].Link=By then
      begin
      Result:=MWNLinks[I];
      Exit
      end;
  Log('[MWN] Failed to find MWNLink corresponding to '+By.Nickname);
  Result:=nil;
end;

// ***************************************************************

procedure TMWNLink.Execute;
var
  R: Integer;
  Bytes: u_long; 
  Data: string;
  ReadSet: record
    count: u_int;
    Socket: TSocket;
    end;
  TimeVal: TTimeVal;
begin
  Log('[MWNLINK] Link with '+Link.Nickname+' ready.');

  repeat
    Link.CheckForData;

    while Queue<>'' do
      begin
      Bytes:=send(MWNSocket, Queue[1], Length(Queue), 0);
      if Bytes=0 then 
        begin
        MWNSocket:=0;
        Log('[MWNLINK] Link to '+Link.NickName+' closed gracefully.');
        Link.Owner.OnDisconnect(Link);
        Break;
        end;
      if Bytes=SOCKET_ERROR then 
        begin
        MWNSocket:=0;
        Log('[MWNLINK] Link to '+Link.NickName+' terminated with error '+IntToStr(WSAGetLastError));
        Link.Owner.OnDisconnect(Link);
        Break;
        end;
      Delete(Queue, 1, Bytes);
      Log(' [MWNLINK] Sent '+IntToStr(Bytes)+' bytes to the server.', 2);
      end;

    TimeVal.tv_sec:=0;
    TimeVal.tv_usec:=0;

    if MWNSocket<>0 then
     repeat
      ReadSet.count:=1;
      ReadSet.Socket:=MWNSocket;
      R:=select(0, @ReadSet, nil, nil, @TimeVal);
      if R=SOCKET_ERROR then
        begin
        MWNSocket:=0;
        Log('[MWNLINK] Link to '+Link.NickName+' terminated with error '+IntToStr(WSAGetLastError)+' in select()');
        closesocket(Link.Socket); Link.Socket:=0;
        Break;
        end;

      if (ReadSet.count=0)or(R=0) then
        Break;         // nothing to read

      R := ioctlsocket(MWNSocket, FIONREAD, Bytes);
      if R=SOCKET_ERROR then
        begin
        MWNSocket:=0;
        Log('[MWNLINK] Link to '+Link.NickName+' terminated with error '+IntToStr(WSAGetLastError));
        closesocket(Link.Socket); Link.Socket:=0;
        Break;
        end;
      
      if Bytes=0 then 
        begin
        MWNSocket:=0;
        Log('[MWNLINK] Link to '+Link.NickName+' closed gracefully.');
        closesocket(Link.Socket); Link.Socket:=0;
        Break;
        end;

      SetLength(Data, Bytes);
      Bytes := recv(MWNSocket, Data[1], Bytes, 0);
      if Bytes=0 then 
        begin
        MWNSocket:=0;
        Log('[MWNLINK] Link to '+Link.NickName+' closed gracefully.');
        closesocket(Link.Socket); Link.Socket:=0;
        Break;
        end;
      if Bytes=SOCKET_ERROR then 
        begin
        MWNSocket:=0;
        Log('[MWNLINK] Link to '+Link.NickName+' terminated with error '+IntToStr(WSAGetLastError));
        closesocket(Link.Socket); Link.Socket:=0;
        Break;
        end;
      SetLength(Data, Bytes);
      Link.Write(Data);
     until False;

    Sleep(10);
  until Link.Owner.Stop or Link.Owner.Finished or (MWNSocket=0);

  if MWNSocket<>0 then
    begin closesocket(MWNSocket); MWNSocket:=0; end;
  if Link.Socket<>0 then
    begin closesocket(Link.Socket); Link.Socket:=0; end;
end;

end.

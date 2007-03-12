library SocksFinder;

// SOCKS dox: http://www.smartftp.com/Products/SmartFTP/RFC/socks4.protocol

uses
  Windows, SysUtils, Classes, IniFiles, WinSock, WinInet, Data in '..\Data.pas';

procedure DefaultLogger(P: PChar); stdcall;
var
  F: text;
  S: string;
begin
  S:=P;

  {$I-}
  Assign(F, ExtractFilePath(ParamStr(0))+'SocksFinder.log');
  Append(F);
  WriteLn(F, S);
  Close(f);
  {$I+}
  if IOResult<>0 then ;
end;

procedure DefaultIdleProc; stdcall;
begin
end;

type
  TLogger = procedure (S: PChar); stdcall;
  TIdleProc = procedure; stdcall;

var
  Logger: TLogger = DefaultLogger;
  IdleProc: TIdleProc = DefaultIdleProc;

procedure SetLogger(ALogger: TLogger); stdcall;
begin
  Logger:=ALogger;
end;

procedure SetIdleProc(AIdleProc: TIdleProc); stdcall;
begin
  IdleProc:=AIdleProc;
end;

procedure Log(S: string);
begin
  Logger(PChar('['+TimeToStr(Now)+'] '+S));
end;

resourcestring
  ProxyURLs='http://nntime.com/socks1.htm?|http://www.samair.ru/proxy/socks.htm?|'+
            'http://nntime.com/socks2.htm?|http://www.samair.ru/proxy/socks2.htm?|'+
            'http://nntime.com/socks3.htm?|http://www.samair.ru/proxy/socks3.htm?|'+
            'http://nntime.com/socks4.htm?|http://www.samair.ru/proxy/socks4.htm?|'+
            'http://nntime.com/socks5.htm?|http://www.samair.ru/proxy/socks5.htm?|'+
            'http://nntime.com/socks6.htm?|http://www.samair.ru/proxy/socks6.htm?|'+
            'http://nntime.com/socks7.htm?|http://www.samair.ru/proxy/socks7.htm?|'+
            'http://nntime.com/socks8.htm?|http://www.samair.ru/proxy/socks8.htm?|'+
            'http://nntime.com/socks9.htm?|http://www.samair.ru/proxy/socks9.htm?|'+
            'http://nntime.com/socks10.htm?|http://www.samair.ru/proxy/socks10.htm?';

// | separates URLs.
// you can change the URLs with a resource editor without recompiling
// you can add the addresses of any HTML page that has proxies in the 
// form of:
// IP:port [optional data that will be ignored]
// on every line, in the first <pre> tag in the HTML.

// ***************************************************************

function DownloadURL(URL: string): string;
var
  NetHandle: HINTERNET;
  UrlHandle: HINTERNET;
  Buffer: string;
  BytesRead: Cardinal;
  R, Error: Cardinal;
begin
  Log('[WWW] Downloading URL '+URL);
  Result := '';
  NetHandle := InternetOpen('SocksFinder', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);

  if Assigned(NetHandle) then
    begin
    UrlHandle := InternetOpenUrl(NetHandle, PChar(Url), nil, $FFFFFFFF, INTERNET_FLAG_RELOAD, 0);

    if Assigned(UrlHandle) then
      begin
      SetLength(Buffer, 1024); 
      BytesRead:=Length(Buffer); R:=0;
      InternetGetLastResponseInfo(Error, PChar(@Buffer[1]), BytesRead);
      if Error<>0 then
        raise Exception.Create('Internet error');
      // HTTP_QUERY_STATUS_CODE HTTP_QUERY_STATUS_TEXT
      SetLength(Buffer, 1024); 
      BytesRead:=Length(Buffer); R:=0;
      HttpQueryInfo(UrlHandle, HTTP_QUERY_STATUS_CODE, @Buffer[1], BytesRead, R);
      //MessageBox(0, PChar(@Buffer[0]), nil, 0);
      if Copy(Buffer, 1, BytesRead-1)='' then
        R:=200
      else
        R:=StrToInt(Copy(Buffer, 1, BytesRead-1));
      if(R>=400)then
        begin
        SetLength(Buffer, 1024); 
        BytesRead:=Length(Buffer); R:=0;
        HttpQueryInfo(UrlHandle, HTTP_QUERY_STATUS_TEXT, @Buffer[1], BytesRead, R);
        raise Exception.Create('Internet error: '+Copy(Buffer, 1, BytesRead));
        end;

      repeat
        SetLength(Buffer, 1024);
        InternetReadFile(UrlHandle, @Buffer[1], Length(Buffer), BytesRead);
        SetLength(Buffer, BytesRead);
        Result:=Result+Buffer;
      until BytesRead=0;

      InternetCloseHandle(UrlHandle);
      end
    else
      raise Exception.CreateFmt('Cannot open URL %s', [Url]);

    InternetCloseHandle(NetHandle);
    end
  else
    raise Exception.Create('Unable to initialize WinInet');
end;

// ***************************************************************

resourcestring
  MyIPURL = 'http://thecybershadow.net/ip.php';   // any URL that returns only the IP address in plain text (no HTML) will work

var
  MyIP: string;

function GetMyIP: PChar; stdcall;
begin
  if MyIP='' then
    MyIP:=DownloadURL(MyIPURL);
  Result:=PChar(MyIP);
end;

procedure SetMyIP(IP: PChar); stdcall;
begin
  MyIP:=IP;
end;

// ***************************************************************

type
  TSocksPacket=record
    Version, Command: Byte;
    Port: Word;
    IP: TInAddr;
    end;

const
  DummyPacket: string = 'This is a dummy test packet.';

function CheckProxy(Target: PChar): Boolean; stdcall;
var
  Addr: TSockAddrIn;
  Host: PHostEnt;
  ProxySocket, ProxySocket2: TSocket;
  R: Integer;
  Packet: TSocksPacket;
  //Term: Byte;
  PBuf: string;
begin
  Result:=False;
  try
    Log('['+Target+'] Connecting...');

    ProxySocket := socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );

    Addr.sin_family := AF_INET;
    Host:=gethostbyname(PChar(Copy(Target, 1, Pos(':', Target)-1)));  
    if Host=nil then
      raise Exception.Create('Invalid address specified.');
    Addr.sin_addr.s_addr := PInAddr(Host.h_addr_list^).s_addr;
    Addr.sin_port := htons(StrToInt(Copy(Target, Pos(':', Target)+1, 100)));

    if connect( ProxySocket, Addr, sizeof(Addr) )=SOCKET_ERROR then
      begin
      Log('['+Target+'] Failed to connect (Error '+IntToStr(WSAGetLastError)+').');
      Exit;
      end;
    //if Terminated then Exit;

    Packet.Version:=4;
    Packet.Command:=2;  // BIND
    Packet.Port:=0;
    Packet.IP.S_addr:=inet_addr(PChar(GetMyIP));
    send(ProxySocket, Packet, SizeOf(Packet), 0);
    //Term:=0;
    //send(ProxySocket, Term, 1, 0);  // ending NULL byte
    //if Terminated then Exit;

    R:=recv(ProxySocket, Packet, SizeOf(Packet), 0);
    if R=SOCKET_ERROR then
      begin
      Log('['+Target+'] Error while receiving reply ('+IntToStr(WSAGetLastError)+').');
      closesocket(ProxySocket);
      Exit;
      end;
    if R=0 then
      begin
      Log('['+Target+'] Server closed connection.');
      closesocket(ProxySocket);
      Exit;
      end;
    //if Terminated then Exit;

    if Packet.Command=90 then 
      Log('['+Target+'] Received reply : Request granted ('+inet_ntoa(Packet.IP)+':'+IntToStr(Packet.Port)+')')
    else
      begin
      Log('['+Target+'] Received bad reply ('+IntToStr(Packet.Command)+').');
      closesocket(ProxySocket);
      Exit;
      end;

    Log('['+Target+'] Connecting to secondary connection...');

    ProxySocket2 := socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );

    Addr.sin_family := AF_INET;
    Host:=gethostbyname(PChar(Copy(Target, 1, Pos(':', Target)-1)));
    //Addr.sin_addr := Packet.IP;
    Addr.sin_addr.s_addr := PInAddr(Host.h_addr_list^).s_addr;
    Addr.sin_port := htons(Packet.Port);

    if connect( ProxySocket2, Addr, sizeof(Addr) )=SOCKET_ERROR then
      begin
      Log('['+Target+'] Failed to connect (Error '+IntToStr(WSAGetLastError)+').');
      closesocket(ProxySocket);
      Exit;
      end;
    Log('['+Target+'] Connected.');

    R:=recv(ProxySocket, Packet, SizeOf(Packet), 0);
    if R=0 then
      begin
      Log('['+Target+'] Error while receiving second reply ('+IntToStr(WSAGetLastError)+').');
      closesocket(ProxySocket);
      closesocket(ProxySocket2);
      Exit;
      end;

    if Packet.Command=90 then 
      Log('['+Target+'] Received second reply : All OK ('+inet_ntoa(Packet.IP)+':'+IntToStr(Packet.Port)+')')
    else
      begin
      Log('['+Target+'] Received bad second reply ('+IntToStr(Packet.Command)+').');
      closesocket(ProxySocket2);
      closesocket(ProxySocket);
      Exit;
      end;

    // some servers need 1 additional byte to be sent via the data connection...
    //Term:=255;
    //send(ProxySocket, Term, 1, 0);
    
    // send a dummy packet through both ends and see if it gets through
    {Packet.Command:=137;
    Packet.Version:=17;
    Packet.Port:=31337;
    Packet.IP.S_addr:=0;
    send(ProxySocket2, Packet, SizeOf(Packet), 0);
    send(ProxySocket, Packet, SizeOf(Packet), 0);}

    PBuf:=DummyPacket;
    send(ProxySocket2, PBuf[1], Length(PBuf), 0);
    PBuf:=DummyPacket;
    send(ProxySocket , PBuf[1], Length(PBuf), 0);
    Log('['+Target+'] Test packets sent.');

    R:=recv(ProxySocket, PBuf[1], Length(PBuf), 0);
    if R=0 then
      begin
      Log('['+Target+'] Error while receiving test packet 1 ('+IntToStr(WSAGetLastError)+').');
      closesocket(ProxySocket);
      closesocket(ProxySocket2);
      Exit;
      end;
    if PBuf=DummyPacket then 
      Log('['+Target+'] Received test packet 1')
    else
      begin
      Log('['+Target+'] Received garbage instead of test packet 1');
      Log('['+Target+'] Expected : '+StrToHex(DummyPacket));
      Log('['+Target+'] Received : '+StrToHex(PBuf));
      closesocket(ProxySocket);
      closesocket(ProxySocket2);
      Exit;
      end;

    //recv(ProxySocket2, Term, 1, 0);
    R:=recv(ProxySocket2, PBuf[1], Length(PBuf), 0);
    if R=0 then
      begin
      Log('['+Target+'] Error while receiving test packet 2 ('+IntToStr(WSAGetLastError)+').');
      closesocket(ProxySocket);
      closesocket(ProxySocket2);
      Exit;
      end;
    if PBuf=DummyPacket then 
      Log('['+Target+'] Received test packet 2')
    else
      begin
      Log('['+Target+'] Received garbage instead of test packet 2');
      Log('['+Target+'] Expected : '+StrToHex(DummyPacket));
      Log('['+Target+'] Received : '+StrToHex(PBuf));
      closesocket(ProxySocket);
      closesocket(ProxySocket2);
      Exit;
      end;

    Log('['+Target+'] All tests successful, proxy accepted');
    closesocket(ProxySocket2);
    closesocket(ProxySocket);
    Result:=True;
  except
    on E: Exception do
      Log('['+Target+'] Exception: '+E.Message);
    end;
end;

// ***************************************************************

resourcestring
  MaxCheckers='5';

var
  ProxyList: TStringList;
  GoodProxy: string;
  ActiveCheckers: Integer;

type
  TProxyChecker=class(TThread)
    //Finished: Boolean;
    Target: string;
    procedure Execute; override;
    end;

procedure TProxyChecker.Execute;
begin
  FreeOnTerminate:=True;
  if CheckProxy(PChar(Target)) then
    GoodProxy:=Target;
  //Finished:=True;
  Dec(ActiveCheckers);
end;

// ***************************************************************

function FindProxy : PChar; stdcall;
var
  HTML, URLs, Address: string;
  ProxyChecker: TProxyChecker;
  C: Integer;
begin
  Log('------------------ '+DateTimeToStr(Now)+' ------------------');
  ProxyList:=TStringList.Create;
  GoodProxy:='';
  URLs:=ProxyURLs+'|';
  GetMyIP;
  while URLs<>'' do
    begin
    try
      HTML:=DownloadURL(Copy(URLs, 1, Pos('|', URLs)-1));
      Delete(URLs, 1, Pos('|', URLs));
    except
      Continue;
      end;
    if(HTML<>'')or(Pos('<pre>', HTML)=0) then
      begin
      Delete(HTML, 1, Pos('<pre>', HTML)+4);
      HTML:=Copy(HTML, 1, Pos('</pre>', HTML)-1);
      while HTML<>'' do
        begin
        while(HTML<>'')and(HTML[1] in [#13,#10,' '])do
          Delete(HTML, 1, 1);
        if HTML='' then Break;
        Address:='';
        while(HTML<>'')and(HTML[1] in ['0'..'9','.',':'])do
          begin
          Address:=Address+HTML[1];
          Delete(HTML, 1, 1);
          end;

        C:=0;
        while(ActiveCheckers>=StrToInt(MaxCheckers))and(GoodProxy='') do
          begin
          IdleProc;
          Sleep(10);
          Inc(C);
          if C=1000 then   // 10 secs timeout
            Dec(ActiveCheckers);
          end;

        if GoodProxy<>'' then
          begin
          Result:=PChar(GoodProxy);
          Exit;
          end;
        
        Inc(ActiveCheckers);
        ProxyChecker:=TProxyChecker.Create(True);
        ProxyChecker.Target:=Address;
        ProxyChecker.Resume;

        // skip to next line
        while(HTML<>'')and not(HTML[1] in [#13,#10])do
          Delete(HTML, 1, 1);
        end;
      end;
    end;
  Result:=nil;
end;

exports
  SetLogger, SetIdleProc,
  SetMyIP,
  GetMyIP, 
  FindProxy, 
  CheckProxy;

end.
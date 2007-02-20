unit IRCModule;  // IRC inter-connectivity module for WormNAT

interface
uses
  Base, Windows, SysUtils, WinSock, Data, IniFiles;

// options
var
  IRCLineLength: Integer;
  IRCDelay: Integer;
  IRCServer: string;
  IRCPort: Integer;
  IRCPassword: string;
  IRCNickLength: Integer;
  IRCSuffix: string;

  WormNETPassword: string;

procedure LoadConfig(F: TCustomIniFile);
  
type
  TIRCModule = class (TModule)
    IRCSocket: TSocket;
    constructor Create; override;
    procedure Main; override;
    procedure Write(From: TLink; S: string); override;
    procedure OnDisconnect(From: TLink); override;
    procedure sendln(S: string);
    end;

implementation

procedure LoadConfig(F: TCustomIniFile);
begin
  IRCLineLength:=F.ReadInteger('IRC',    'LineLength',     425);   // how much chars per line can the IRC server support in notices. Leave about 5% overhead.
  IRCDelay     :=F.ReadInteger('IRC',    'Delay',         2000);   // max delay between lines. Lower = less lag, but too little values will get you kicked for flood!
  IRCServer    :=F.ReadString ('IRC',    'Server',        'wormnet1.team17.com');   // the server where you'll host games
  IRCPort      :=F.ReadInteger('IRC',    'Port',          6667);   // server port
  IRCPassword  :=F.ReadString ('IRC',    'Password',      '*auto*');   // server password - *auto* will use WormNet's password
  IRCNickLength:=F.ReadInteger('IRC',    'NickLength',      15);   // maximum number of characters allowed in nicknames
  IRCSuffix    :=F.ReadString ('IRC',    'Suffix',       '-WormNAT');   // suffix to append to nicknames for WormNAT connections (last characters of your nickname could overlap)
end;

function GenNickname(Nick: string): string;
begin
  Result:=Nick;
  if Copy(Nick, Length(Nick)+1-Length(IRCSuffix), Length(IRCSuffix))=IRCSuffix then
    Exit;
  while Length(Result)>IRCNickLength-Length(IRCSuffix) do
    Delete(Result, Length(Result), 1);
  Result:=Result+IRCSuffix;
end;

constructor TIRCModule.Create;
begin
  inherited;
  IRCSocket:=0;
end;

const
  EchoTest='WormNAT-Echo-Test-String';
  NicknameError=':Nickname is already in use.';  // TODO: check actual IRC response code

procedure TIRCModule.Main;
var
  IRCAddr, WormsAddr: TSockAddrIn;
  IRCHost: PHostEnt;
  WormsSocket: TSocket;
  S, Buffer, BotNick, From, DataMarker: string;
  Bytes: u_long; R, I: Integer;
  Link: TLink;
  ReadSet: record
    count: u_int;
    Socket: TSocket;
    end;
  TimeVal: TTimeVal;
begin
  Log('[IRC] Connecting...');

  NoCapture := True;
  IRCSocket := socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );

  IRCAddr.sin_family := AF_INET;
  IRCHost:=gethostbyname(PChar(IRCServer));  
  if IRCHost=nil then
    begin
    NoCapture := False;
    raise Exception.Create('[IRC] Failed to resolve '+IRCServer+' (Error '+IntToStr(WSAGetLastError)+').');
    end;
  IRCAddr.sin_addr.s_addr := PInAddr(IRCHost.h_addr_list^).s_addr;
  IRCAddr.sin_port := htons( IRCPort );

  if connect( IRCSocket, IRCAddr, sizeof(IRCAddr) )=SOCKET_ERROR then
    begin
    NoCapture := False;
    raise Exception.Create('[IRC] Failed (Error '+IntToStr(WSAGetLastError)+').');
    end;
  NoCapture := False;

  if IRCPassword<>'' then
   if IRCPassword='*auto*' then
    sendln('PASS '+WormNETPassword)
   else
    sendln('PASS '+IRCPassword);

  BotNick:=GenNickname(Nick);
  Log('[IRC] Nick = '+BotNick);
  sendln('NICK '+BotNick+' ');
  sendln('USER Username hostname servername :40 0 '+Location);
  sendln('NOTICE '+BotNick+' :'+EchoTest);

  Buffer:='';
  DataMarker:=' NOTICE '+BotNick+' :';
  repeat
    repeat
      ReadSet.count:=1;
      ReadSet.Socket:=IRCSocket;
      R:=select(0, @ReadSet, nil, nil, @TimeVal);
      if R=SOCKET_ERROR then
        begin
        Finished:=True;
        raise Exception.Create('[IRC] Connection error in select() ('+IntToStr(WSAGetLastError)+').');
        end;

      if (ReadSet.count=0)or(R=0) then
        Break;         // nothing to read

      R:=ioctlsocket(IRCSocket, FIONREAD, Bytes);
      if R=SOCKET_ERROR then
        begin
        Finished:=True;
        raise Exception.Create('[IRC] Connection error ('+IntToStr(WSAGetLastError)+').');
        end;
      if Bytes=0 then
        begin
        Finished:=True;
        raise Exception.Create('[IRC] Connection closed gracefully.');
        end;
      SetLength(S, Bytes);
      R:=recv(IRCSocket, S[1], Bytes, 0);
      if(R=0)or(R=SOCKET_ERROR) then
        begin
        Finished:=True;
        raise Exception.Create('[IRC] Connection error ('+IntToStr(WSAGetLastError)+').');
        end;
      SetLength(S, R);
      Buffer := Buffer + S;
    until False;

    while GetLine(Buffer, S) do
      begin     // :CyberShadow!cybershado@2e01205d.2e099bf0.35556308.18251e65X NOTICE CyberShadow :bla bla test
      Log('[IRC < ] '+S, 2);

      if Copy(S, 1, 4)='PING' then
        sendln('PONG'+Copy(S, 5, 1000));

      if Pos(EchoTest, S)<>0 then
        begin
        Ready:=True;
        Log('[IRC] Ready.');
        end;

      if Pos(NicknameError, S)<>0 then
        begin
        Ready:=False;
        sendln('QUIT');
        Sleep(100);
        closesocket(IRCSocket);
        Finished:=True;
        raise Exception.Create('[IRC] Nickname error...');
        end;

      if Pos(DataMarker, S)<>0 then
        begin
        Delete(S, 1, 1);
        From:=Copy(S, 1, Pos('!', S)-1);
        if (From=Nick)or(From=BotNick) then 
          Continue;

        Delete(S, 1, Pos(DataMarker, S)-1+Length(DataMarker));
        
        if S='' then 
          Continue;
        if not (S[1] in ['!','#','$']) then
          begin
          Log('[IRC] Unexpected notice from '+From+': "'+S+'"', 1);
          Continue;
          end;

        Link:=nil;
        for I:=0 to Length(Links)-1 do
          if(GenNickname(Links[I].Nickname)=GenNickname(From)) and (Links[I].Socket<>0) then
            Link:=Links[I];
        if Link=nil then  // incoming connection
          begin
          NoCapture := True;
          WormsSocket := socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );

          WormsAddr.sin_family := AF_INET;
          WormsAddr.sin_addr.s_addr := inet_addr('127.0.0.1');
          WormsAddr.sin_port := htons( 17011 );

          if connect( WormsSocket, WormsAddr, sizeof(WormsAddr) )=SOCKET_ERROR then
            begin
            Log('[IRC] Failed to connect Link to Worms (Nick='+From+', Error '+IntToStr(WSAGetLastError)+').');
            NoCapture := False;
            Continue;
            end;
	
          NoCapture := False;
          
          Link:=AddLink(From, WormsSocket);
          end;

        case S[1] of
          '!':
            begin
            Log('[IRC] Terminating link with '+From+'.');
            closesocket(Link.Socket); Link.Socket:=0;
            end;
          '#':
            try
              Delete(S, 1, 1);
              S:=Decode64(S);
              Link.Write(S);
            except
              on E: Exception do
                Log('[IRC] Error "'+E.Message+'" when decoding packet');
              end;
          '$':
            try
              Delete(S, 1, 1);
              S:=Decompress(Decode64(S));
              Link.Write(S);
            except
              on E: Exception do
                Log('[IRC] Error "'+E.Message+'" when decoding packet');
              end;
           end;
        end;
      end;

    for I:=0 to Length(Links)-1 do
      Links[I].CheckForData;

    Sleep(10);
  until Stop;
  Log('[IRC] Stopping.');
  sendln('QUIT');
  Sleep(100);
  closesocket(IRCSocket);
  Finished:=True;
end;

procedure TIRCModule.sendln(S: string);
begin
  Log('[IRC > ] '+S, 2);
  S:=S+#13#10;
  if send(IRCSocket, S[1], Length(S), 0)<>Length(S) then
    Log('[IRC > Failed ('+IntToStr(WSAGetLastError)+') ]');
end;

procedure TIRCModule.Write(From: TLink; S: string); 
var
  I1, I2, L, R: Integer;
  S1, S2: string;
begin
  L:=Length(S);
  while S<>'' do
    begin
    
    // data -> Base64
    I1:=1;
    while(I1<=Length(S)) and (Length(Encode64(Copy(S, 1, I1)))<=IRCLineLength) do
      Inc(I1);
    S1:=Encode64(Copy(S, 1, I1-1));

    // data -> zlib -> Base64
    I2:=1;
    while(I2<=Length(S)) and (Length(Encode64(Compress(Copy(S, 1, I2))))<=IRCLineLength) do
      Inc(I2);
    S2:=Encode64(Compress(Copy(S, 1, I2-1)));

    if I1=I2 then
      // if the amount of data sent is the same, send the encoding that's shortest
      if Length(S1)<Length(S2) then
        R:=1
      else
        R:=2
    else
      // send the encoding that fits most bytes
      if I1>I2 then
        R:=1
      else
        R:=2;

    if R=1 then
      begin
      Delete(S, 1, I1-1);
      sendln('NOTICE '+GenNickname(From.Nickname)+' :#'+S1);
      end
    else
      begin
      Delete(S, 1, I2-1);
      sendln('NOTICE '+GenNickname(From.Nickname)+' :$'+S2);
      end;

    Sleep(IRCDelay);
    end;
  Log(' [IRC] Forwarded '+IntToStr(L)+' bytes.', 2);
end;

procedure TIRCModule.OnDisconnect(From: TLink); 
begin
  sendln('NOTICE '+GenNickname(From.Nickname)+' :!');
end;

end.

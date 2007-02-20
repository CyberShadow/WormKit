library wkWormNAT;

{$IMAGEBASE $5a800000}

uses Windows, SysUtils, Classes, WinSock, madCodeHook, IniFiles, Base, Data, IRCModule, SOCKSModule, MWNModule, Listener, LingerIRC;

const
  InfoURL = 'http://wormnat.xeon.cc/';
  FakeAddress = {'This is a WormNAT game - see '+}InfoURL;

// ***************************************************************

var
  ModuleThread: THandle;
  ModuleError: string;

procedure ModuleThreadProc(Foo: Pointer); stdcall;
var
  Module: TModule;    // local thread var
begin
  if Mode='IRC' then
    Module:=TIRCModule.Create
  else
  if Mode='SOCKS' then
    Module:=TSOCKSModule.Create
  else
  if Mode='MWN' then
    Module:=TMWNModule.Create
  else
    begin
    Log('[WTF] Unknown network mode: '+Mode);
    Exit;
    end;
  ActiveModule:=Module;
  ModuleError:='';
  try
    Module.Main;
  except
    on E: Exception do
      ModuleError:=E.Message;
    end;
  Module.Finished:=True;
end;

procedure StartModule;
var 
  ThreadID: Cardinal;
begin
  Sleep(50);
  if ActiveModule=nil then
    ModuleThread:=CreateThread(nil, 0, @ModuleThreadProc, nil, 0, ThreadID);
end;

procedure StopModule;
var C: Integer;
begin
  if ActiveModule<>nil then
    try
      begin
      ActiveModule.Stop:=True;
      C:=0;
      repeat
        Sleep(10); Inc(C);
      until(C=50)or ActiveModule.Finished;

      if not ActiveModule.Finished then
        TerminateThread(ModuleThread, 0);
      try
        ActiveModule.Free;
      except
        on E: Exception do
          Log('Error while freeing last module: '+E.Message);
        end;
      end;
    except
      on E: Exception do
        Log('Error while terminating last module: '+E.Message);
      end;
  ActiveModule:=nil;
end;

// ***************************************************************

var
  Config: TMemIniFile;
 
procedure InitConfig;
begin
  Config := TMemIniFile.Create(ExtractFilePath(ParamStr(0))+'WormNAT.ini');
end;

procedure LoadNetConfig(Config: TMemIniFile);
begin
  Mode:=Config.ReadString ('WormNAT','Mode',         'IRC');   // your hosting back-end
  if Mode='IRC' then
    IRCModule.LoadConfig(Config)
  else
  if Mode='SOCKS' then
    SOCKSModule.LoadConfig(Config)
  else
  if Mode='MWN' then
    MWNModule.LoadConfig(Config)
  else
    Log('[WTF] Unknown network mode: '+Mode);
end;

procedure ReloadConfig;
begin
  LoopbackPort :=Config.ReadInteger('WormNAT','LoopbackPort', 17017);   // port for loopback connections (any free port).
  Server       :=Config.ReadBool   ('WormNAT','Server',        True);   // act as a WormNAT server - disable if you don't have NAT problems and only want to play with people hosting with WormNAT
  NickOverride :=Config.ReadString ('WormNAT','NickOverride',  ''  );   // override the nickname, debug option...
  LogLevel     :=Config.ReadInteger('WormNAT','LogLevel',         1);   // how verbose logging to do
  LameHacks    :=Config.ReadBool   ('WormNAT','LameHacks',    False);   // don't ask

  LoadNetConfig(Config);

  if MWNPort>0 then
    Mode:='MWN';
end;

// ***************************************************************

function GetMyIP: PChar; stdcall; external 'SocksFinder.dll';
procedure SetMyIP(IP: PChar); stdcall; external 'SocksFinder.dll';

// connection parameters
var
  ParamList: TStringList; GettingParams: Boolean; Params: TMemIniFile; ParamIdleTime: Integer;
  MyRealHost, MyGameName, MyRealGameName: string;

function ProcessIRCin : string;
var 
  Ln, S, From, NoticeMarker: string;
  I: Integer;
begin
  NoticeMarker:=' NOTICE '+Nick+' :';
  Result:='';
  while GetLine(IRCin, Ln) do
    begin
    // process Ln
    {if Pos(':End of /LIST', Ln)<>0 then
      begin
      //S:=Copy(Ln, 1, Pos(':End of /LIST', Ln)-1) + '#NonExistingChannel 31337 :';
      S:=':wormnet1.team17.com 322 '+Nick+' #NonExistingChannel 31337 :';
      Result:=Result + S + #13#10;
      Log('>> '+S);
      end;}
    if(Pos('[WormNATRouteOn:', Ln)<>0)and(MWNPort=0) then
      begin
      S:=Copy(Ln, Pos('[WormNATRouteOn:', Ln)+16, 1000);
      S:=Copy(S, 1, Pos(']', S)-1);
      MWNPort:=StrToIntDef(S, 0);
      Mode:='MWN';
      Log('Switched to MyWormNet mode, port '+IntToStr(MWNPort));
      end;
    if(Pos('[WormNATRouteOn:', Ln)<>0)and(MWNPort=0) then
      begin
      S:=Copy(Ln, Pos('[WormNATRouteOn:', Ln)+16, 1000);
      S:=Copy(S, 1, Pos(']', S)-1);
      MWNPort:=StrToIntDef(S, 0);
      Mode:='MWN';
      Log('Switched to MyWormNet mode, port '+IntToStr(MWNPort));
      end;
    if Pos(NoticeMarker, Ln)<>0 then
      begin
      S:=Ln;
      Delete(S, 1, 1);  // :
      From:=Copy(S, 1, Pos('!', S)-1);
      Delete(S, 1, Pos(NoticeMarker, S)-1+Length(NoticeMarker));

      if From<>Nick then   // don't process our own messages
        begin
        if Copy(S, 1, 9)='GETPARAMS' then
         if ActiveModule=nil then
          Log('[WTF] No module started but got GETPARAMS request from '+From)
         else
          begin
          ParamList:=TStringList.Create;
          Config.ReadSectionValues(Mode, ParamList);
          ParamList.Text:=ParamList.Text+ActiveModule.PerUserConfig(Copy(S, 11, 1000), From);
          ParamList.Insert(0, '[WormNAT]');    // insert lines at the top
          ParamList.Insert(1, 'Mode='+Mode);
          ParamList.Insert(2, '['+Mode+']');
          for I:=0 to ParamList.Count-1 do
            begin
            S:='NOTICE '+From+' :PARAM '+ParamList[I]+#13#10;
            if LingeringIRC<>0 then
              LingeringSendLn(S, '')
            else
              send(IRC, S[1], Length(S), 0);
            end;

          S:='NOTICE '+From+' :PARAMEND'+#13#10;
          if LingeringIRC<>0 then
            LingeringSendLn(S, '')
          else
            send(IRC, S[1], Length(S), 0);

          FreeAndNil(ParamList);
          end;

        if Copy(S, 1, 6)='PARAM ' then
          begin
          if (ParamList=nil) or not GettingParams then
            Log('[WTF] Unexpected PARAM from '+From+'!')
          else
            begin
            Delete(S, 1, 6);
            Log('[PARAM] '+S, 1);
            ParamList.Add(S);
            ParamIdleTime:=0;
            end;
          end;

        if Copy(S, 1, 8)='PARAMEND' then
          begin
          if (ParamList=nil) or not GettingParams then
            Log('[WTF] Unexpected PARAMEND from '+From+'!')
          else
            begin
            Params:=TMemIniFile.Create('');
            Params.SetStrings(ParamList);
            LoadNetConfig(Params);
            Params.Free;
            ParamList.Free;
            GettingParams:=False;
            end;
          end;
        end;

      end;
    Log('[<<<]'+Ln, 2);
    Result:=Result+Ln+#13#10;
    end;
end;

function ProcessIRCout : string;
var Ln, S: string;
begin
  Result:='';
  while GetLine(IRCout, Ln) do
    begin
    // process Ln
    if Copy(Ln, 1, 5)='NICK ' then
      begin
      if Pos(IRCSuffix, Ln)<>0 then
        begin
        IRC:=0;
        Log('[ONOES] CAPTURED OWN CONNECTION');
        end
      else
        if NickOverride='' then
          begin
          Nick:=Copy(Ln, 6, Length(Ln)-6);
          Log('[DEBUG] Nick='+Nick, 1);
          end
        else
          begin
          Ln:='NICK '+NickOverride;
          Nick:=NickOverride;
          Log('[DEBUG] NickOverride='+Nick, 1);
          end;
      end;
    if Copy(Ln, 1, 5)='USER ' then
      begin
      Location:=Copy(Ln, Length(Ln)-3, 3);
      Log('[DEBUG] Location='+Location, 1);
      if LameHacks then
        begin
        S:=Copy(Ln, 1, Pos(':', Ln));
        Delete(Ln, 1, Pos(':', Ln));
        S:=S+Copy(Ln, 1, Pos(' ', Ln));
        Delete(Ln, 1, Pos(' ', Ln));
        S:=S+'11 ';
        Delete(Ln, 1, Pos(' ', Ln));
        S:=S+Ln;
        Ln:=S;
        end;
      end;
    if Copy(Ln, 1, 5)='PASS ' then
      begin
      WormNETPassword:=Copy(Ln, 6, Length(Ln)-5);
      Log('[DEBUG] WormNETPassword='+WormNETPassword, 1);
      end;
    if UpperCase(Copy(Ln, 1, 8))='PRIVMSG ' then
      begin
      if LameHacks then
        Insert(#3'4', Ln, Pos(':', Ln)+1);
      end;
    if Copy(Ln, 1, 4)='QUIT' then
      //if LingeringIRC=0 then
        Ln:='';
    Log('[>>>]'+Ln, 2);
    if Ln<>'' then
      Result:=Result+Ln+#13#10;
    end;
end;

function ProcessHTTPin : string;
var Ln: string; 
  GameName, Player, Address, Tail: string;
begin
  Result:='';
  while GetLine(HTTPin, Ln) do
    begin
    // process Ln
    if (Copy(Ln, 1, 6)='<GAME ') and (Pos(' '+InfoURL+' ', Ln)<>0) then
      begin
      Delete(Ln, 1, 6);
      GameName:=Copy(Ln, 1, Pos(' ', Ln)-1); Delete(Ln, 1, Pos(' ', Ln));
      Player  :=Copy(Ln, 1, Pos(' ', Ln)-1); Delete(Ln, 1, Pos(' ', Ln));
      Address :=Copy(Ln, 1, Pos(' ', Ln)-1); Delete(Ln, 1, Pos(' ', Ln));
      Tail:=Ln;

      if Pos(InfoURL, Address)<>0 then   // it's a WormNAT game!
       if Player=Nick then       // it's the game we just created
        begin
        if MyGameName=GameName then
          begin
          Address:=MyRealHost;
          GameName:=MyRealGameName;
          Log('Found my game ('+MyGameName+' @ '+MyRealHost+')', 2);
          end;
        end
       else
        begin
        Log('Found WormNAT game: '+Player, 2);
        Address:='WormNAT:'+Player;
        end;

      Ln:='<GAME '+GameName+' '+Player+' '+Address+' '+Tail;
      end;
    Result:=Result+Ln+#13#10;
    end;
end;

function ProcessHTTPout : string;
var Ln: string; P: Integer;  C: Integer;
begin
  Result:='';
  while GetLine(HTTPout, Ln) do
    begin
    // process Ln
    if Copy(Ln, 1, 4)='GET ' then
      try
        Log('[WWW] '+Ln, 1);
        // GET Http://wormnet1.team17.com:80/wormageddonweb/Game.asp?Cmd=Create&Name=ßCyberShadow-MD&HostIP=http://wormnat.xeon.cc/&Nick=CyberShadow-MD&Chan=AnythingGoes&Loc=40&Type=0 HTTP/1.0
        if (Pos('/Game.asp?Cmd=Create&', Ln)<>0) and (Pos('HostIP=', Ln)<>0) and Server then
          begin
          P:=Pos('Name=',Ln) + 5;
          MyGameName:=Ln; Delete(MyGameName, 1, P-1); MyGameName:=Copy(MyGameName, 1, Pos('&', MyGameName)-1);
          if(Pos(Nick, MyGameName)<>0)and(Length(MyGameName)-Length(Nick)<3)then
            begin
            MyRealGameName:=MyGameName;
            Delete(Ln, P, Length(MyGameName));
            Insert(InfoURL, Ln, P);
            MyGameName:=InfoURL;
            end;{}
          P:=Pos('HostIP=', Ln) + 7;
          MyRealHost:=Ln; Delete(MyRealHost, 1, P-1); MyRealHost:=Copy(MyRealHost, 1, Pos('&', MyRealHost)-1);
          Delete(Ln, P, Length(MyRealHost));
          Insert(FakeAddress, Ln, P);
          Log('Game creation: '+MyRealHost+' substituted with '+InfoURL, 2);
          ReloadConfig; // reload standard server parameters
          if ActiveModule<>nil then
            begin
            Log('Stopping current module...');
            StopModule;
            end;
          Log('Starting module "'+Mode+'"...');
          StartModule;
          C:=0;
          repeat
            Sleep(10); Inc(C); 
            if C=3000 then      // 30 secs
              begin
              Log('Time-out while starting module.');
              StopModule;
              raise Exception.Create('Failed to start module '+Mode+'.');
              end;
          until (ActiveModule<>nil)and(ActiveModule.Ready or ActiveModule.Finished);
          if ActiveModule.Ready then
            begin
            Log('Module is ready.');
            DoLingering:=True;
            end
          else
            begin
            Log('Module failed to initialize, aborting.');
            if ModuleError<>'' then
              raise Exception.Create(ModuleError)
            else
              raise Exception.Create('Module '+Mode+' failed to initialize.');
            end;
          end;
        // GET Http://wormnet1.team17.com:80/wormageddonweb/Game.asp?Cmd=Close&GameID=1196270&Name=-CyberShadow-MD&HostID=&GuestID=&GameType=0 HTTP/1.0
        if (Pos('/Game.asp?Cmd=Close&', Ln)<>0) and (Pos('HostIP=', Ln)<>0) and Server then	
          begin
          P:=Pos('Name=',Ln) + 5;
          MyGameName:=Ln; Delete(MyGameName, 1, P-1); MyGameName:=Copy(MyGameName, 1, Pos('&', MyGameName)-1);
          {if(Pos(Nick, MyGameName)<>0)and(Length(MyGameName)-Length(Nick)<3)then
            begin
            Delete(Ln, P, Length(MyGameName));
            Insert(InfoURL, Ln, P);
            MyGameName:=InfoURL;
            end;}
          P:=Pos('HostIP=', Ln) + 7;
          MyRealHost:=Ln; Delete(MyRealHost, 1, P-1); MyRealHost:=Copy(MyRealHost, 1, Pos('&', MyRealHost)-1);
          Delete(Ln, P, Length(MyRealHost));
          Insert(FakeAddress, Ln, P);
          Log('Game close: '+MyRealHost+' substituted with '+InfoURL);
          end;

        except
          on E: Exception do 
            begin
            //Ln:=''; HTTPout:=''; Result:='';
            Log('[HTTP] Error in processing GET request: '+E.Message);
            HTTPin:='';
            HTTPin2:='HTTP/1.0 200 OK'#13#10'Error: : '+E.Message+#13#10#13#10+'Error: '+E.Message+#13#10;
            
            Exit;
            end;
          end;

    Result:=Result+Ln+#13#10;
    end;
end;

// ***************************************************************

var 
  connectNext : function (s: TSocket; name: PSockAddrIn; NameLen: Integer) : Integer;  stdcall;
  sendNext : function (s: TSocket; var Buf; len, flags: Integer): Integer; stdcall;
  recvNext : function (s: TSocket; var Buf; len, flags: Integer): Integer; stdcall;
  ioctlsocketNext : function(s: TSocket; cmd: DWORD; var arg: u_long): Integer; stdcall;
  gethostbynameNext : function (name: PChar): PHostEnt; stdcall;
  closesocketNext : function(s: TSocket): Integer; stdcall;
  WSAAsyncSelectNext : function (s: TSocket; HWindow: HWND; wMsg: u_int; lEvent: Longint): Integer; stdcall;

// ***************************************************************

// return True on an error
function CheckIRC : Boolean;
var
  Bytes: u_long; R: Integer;
  Data: string;
begin
  Result:=False;
  repeat
    R := ioctlsocketNext(IRC or LingeringIRC, FIONREAD, Bytes);
    if R<>0 then 
      begin 
      Log('Error '+IntToStr(WSAGetLastError)+' in CheckIRC');
      Result:=True; 
      Break; 
      end;
    if Bytes=0 then
      Break;
    SetLength(Data, Bytes);
    Bytes := recvNext(IRC or LingeringIRC, Data[1], Bytes, 0);
    if(Bytes=0)or(Bytes>Length(Data))or(Bytes=SOCKET_ERROR) then 
      begin 
      Log('Error '+IntToStr(WSAGetLastError)+' in CheckIRC');
      Result:=True; 
      Break; 
      end;
    SetLength(Data, Bytes);
    IRCin := IRCin + Data;
    IRCin2 := IRCin2 + ProcessIRCin;
  until False;
end;

function CheckHTTP : Boolean;
var
  Bytes: u_long; R: Integer;
  Data: string;
begin
  Result:=False;
  repeat
    R := ioctlsocketNext(HTTP, FIONREAD, Bytes);
    if R<>0 then 
      begin 
      Log('Error '+IntToStr(WSAGetLastError)+' in CheckHTTP');
      Result:=True; 
      Break; 
      end;
    if Bytes=0 then 
      Break;
    SetLength(Data, Bytes);
    Bytes := recvNext(HTTP, Data[1], Bytes, 0);
    if(Bytes=0)or(Bytes>Length(Data))or(Bytes=SOCKET_ERROR) then 
      begin 
      Log('Error '+IntToStr(WSAGetLastError)+' in CheckHTTP');
      Result:=True; 
      Break; 
      end;
    SetLength(Data, Bytes);
    HTTPin := HTTPin + Data;
    HTTPin2 := HTTPin2 + ProcessHTTPin;
  until False;
end;

function connectCallback(s: TSocket; name: PSockAddrIn; NameLen: Integer) : Integer;  stdcall;
var
  Data: string; C: Integer;
begin
  try
    if(NameLen>=8)and not NoCapture then
      case ntohs(name.sin_port) of
        6666, 6667, 6677:
          begin
          //Log('IRC socket = 0x'+IntToHex(s, 0), 2);
          with name.sin_addr.S_un_b do
            Log('IRC connect to '+inet_ntoa(name.sin_addr)+':'+IntToStr(ntohs(name.sin_port))+', socket=0x'+IntToHex(s, 0), 1);
          IRC := s;
          IRCin:=''; IRCin2:=''; IRCout:='';
          StopLingering;
          StartListener;
          WormNetServer:=inet_ntoa(name.sin_addr);
          MWNPort:=0;
          //Log('Caught IRC');
          end;
        80:
          begin
          //Log('HTTP socket = 0x'+IntToHex(s, 0), 2);
          Log('HTTP connect to '+inet_ntoa(name.sin_addr)+':'+IntToStr(ntohs(name.sin_port))+', socket=0x'+IntToHex(s, 0), 1);
          HTTP := s;
          HTTPin:=''; HTTPin2:=''; HTTPout:='';
          //Log('Caught HTTP');
          end;
        17011:
          begin
          //Log('Game socket = 0x'+IntToHex(s, 0), 2);
          with name.sin_addr.S_un_b do
            Log('GAME connect to '+inet_ntoa(name.sin_addr)+':'+IntToStr(ntohs(name.sin_port))+', socket=0x'+IntToHex(s, 0), 1);
          Game := s;
          DoLingering:=False;
          if inet_ntoa(name.sin_addr)='127.0.0.1' then
            begin
            if HostPlayer='' then
              Log('[WTF] Unexpected localhost connection')
            else
            if IRC=0 then
              Log('[WTF] no IRC connection')
            else
              begin
              Log('Querying connection parameters from '+HostPlayer+' ...');
              GettingParams := True; ParamList := TStringList.Create;
              if MyRealHost='' then
                begin
                Log('Detecting external IP...');
                NoCapture := True;
                MyRealHost:=GetMyIP;
                NoCapture := False;
                Log('MyRealHost='+MyRealHost, 1);
                end;
              Data:='NOTICE '+HostPlayer+' :GETPARAMS '+MyRealHost+#13#10;
              sendNext(IRC, Data[1], Length(Data), 0);
              ParamIdleTime:=0;
              Log('Waiting for parameters...', 1);
              repeat
                if CheckIRC then
                  begin
                  Log('Error in CheckIRC...');
                  GettingParams:=False;
                  Result:=0; WSASetLastError(WSAEACCES);
                  Exit;
                  end;
                Sleep(10); Inc(ParamIdleTime); 
                if ParamIdleTime>=1000 then
                  begin
                  Log('Time-out while receiving parameters.');
                  GettingParams:=false;
                  Result:=0; WSASetLastError(WSAEACCES);
                  Exit;
                  end;
              until not GettingParams;
              Log('Connection parameters accepted.');
              if ActiveModule<>nil then
                begin
                Log('Stopping current module...');
                StopModule;
                end;
              Log('Starting module "'+Mode+'"...');
              StartModule;
              C:=0;
              repeat
                Sleep(10); Inc(C); 
                if C=3000 then      // 30 secs
                  begin
                  Log('Time-out while starting module.');
                  StopModule;
                  Result:=0; WSASetLastError(WSAEACCES);
                  Exit;
                  end;
              until (ActiveModule<>nil)and(ActiveModule.Ready or ActiveModule.Finished);
              if ActiveModule.Ready then
                begin
                Log('Module is ready, redirecting connection.');
                name.sin_port := htons( LoopbackPort );
                end
              else
                begin
                Log('Module failed to initialize, aborting.');
                Result:=0; WSASetLastError(WSAEACCES);
                Exit;
                end;
              end;
            end;
          end;
        else
          begin
          with name.sin_addr.S_un_b do
            Log('Unprocessed connect to '+inet_ntoa(name.sin_addr)+':'+IntToStr(ntohs(name.sin_port))+', socket=0x'+IntToHex(s, 0), 1);
          end;
        end;
  except
    on E: Exception do
      Log('Unhandled exception in connect: '+E.Message);
    end;
  Result:=connectNext(s, name, NameLen);
end;

// ***************************************************************

function makestr(var Data; len: Integer) : string;
begin
  SetLength(Result, len);
  Move(Data, Result[1], len);
end;

function sendCallback(s: TSocket; var Buf; len, flags: Integer): Integer; stdcall;
var Data: string;
begin
  //if(@Buf<>nil)and(len>0) then
  try
    if flags<>0 then
      begin
      Log('[WTF] recv with non-zero flags (0x'+IntToHex(flags, 0)+'), socket=0x'+IntToHex(s, 0));
      end;
    if @Buf=nil then
      begin
      Log('[WTF] buf=nil, socket=0x'+IntToHex(s, 0));
      end;
    if len=0 then
      begin
      Log('[WTF] len=0, socket=0x'+IntToHex(s, 0));
      end;
    if s=IRC{ or LingeringIRC} then
      begin
      AppendTo('irc.log', makestr(Buf, len));
      IRCout:=IRCout + makestr(Buf, len);
      Data:=ProcessIRCout;
      if Length(Data)>0 then
        sendNext(s, Data[1], Length(Data), flags);
      Result:=len;
      Exit;
      end;
    if s=HTTP then
      begin
      AppendTo('http.log', '>'+makestr(Buf, len));
      HTTPout:=HTTPout + makestr(Buf, len);
      Data:=ProcessHTTPout;
      if Length(Data)>0 then
        sendNext(s, Data[1], Length(Data), flags);
      Result:=len;
      Exit;
      end;
  except
    on E: Exception do
      Log('Unhandled exception in send: '+E.Message);
    end;
  Result:=sendNext(s, Buf, len, flags);
end;

function recvCallback(s: TSocket; var Buf; len, flags: Integer): Integer; stdcall;
begin
  try
    if flags<>0 then
      Log('[WTF] recv with non-zero flags (0x'+IntToHex(flags, 0)+'), socket=0x'+IntToHex(s, 0));

    if s=IRC or LingeringIRC then
      begin
      Result:=0;
      Log('Entering IRC recv; len='+IntToStr(len), 3);
      if CheckIRC then 
        begin
        Log('CheckIRC failed in recv');
        SetLastError(WSAEACCES);
        Exit;
        end;
      if Length(IRCin2)=0 then
        begin
        Log('No data; returning WSAEWOULDBLOCK', 3);
        Result:=SOCKET_ERROR;
        SetLastError(WSAEWOULDBLOCK);
        Exit;
        end;
      if len>Length(IRCin2) then
        len:=Length(IRCin2);
      AppendTo('irc.log', Copy(IRCin2, 1, len));
      Move(IRCin2[1], Buf, len);
      Delete(IRCin2, 1, len);
      Result:=len;
      Log('Exiting IRC recv; len='+IntToStr(len), 3);
      Exit;
      end;
    if s=HTTP then
      begin
      Result:=0;
      Log('Entering HTTP recv; len='+IntToStr(len), 3);
      if CheckHTTP then 
        begin
        Log('CheckHTTP failed in recv');
        SetLastError(WSAEACCES);
        Exit;
        end;
      if Length(HTTPin2)=0 then
        begin
        Log('No data; returning WSAEWOULDBLOCK', 3);
        Result:=SOCKET_ERROR;
        SetLastError(WSAEWOULDBLOCK);
        Exit;
        end;
      if len>Length(HTTPin2) then
        len:=Length(HTTPin2);
      AppendTo('HTTP.log', Copy(HTTPin2, 1, len));
      Move(HTTPin2[1], Buf, len);
      Delete(HTTPin2, 1, len);
      Result:=len;
      Log('Exiting HTTP recv; len='+IntToStr(len), 3);
      Exit;
      end;
  except
    on E: Exception do
      Log('Unhandled exception in recv: '+E.Message);
    end;
  Result:=recvNext(s, Buf, len, flags);
end;

function ioctlsocketCallback(s: TSocket; cmd: DWORD; var arg: u_long): Integer; stdcall;
begin
  try
    if cmd=FIONREAD then  // FIONREAD, get # bytes to read
      begin
      if s=IRC or LingeringIRC then
        begin
        Log('Entering ioctlsocket', 3);
        ioctlsocketNext(s, cmd, arg);
        Log('Real buffer: '+IntToStr(arg), 3);
        CheckIRC;
        arg:=Length(IRCin2);
        Log('My arg: '+IntToStr(arg), 3);
        Result:=0;
        Exit;
        end;
      if s=HTTP then
        begin
        CheckHTTP;
        arg:=Length(HTTPin2);
        Result:=0;
        Exit;
        end;
      end;
    if cmd=FIONBIO then
      Log('[WARN] Socket 0x'+IntToHex(s, 0)+' is setting non-blocking mode to '+IntToStr(arg));
  except
    on E: Exception do
      Log('Unhandled exception in ioctlsocket: '+E.Message);
    end;
  Result:=ioctlsocketNext(s, cmd, arg)
end;

function gethostbynameCallback(name: PChar): PHostEnt; stdcall;
begin
  try
    if Copy(Name, 1, 8)='WormNAT:' then
      begin
      HostPlayer:=Copy(Name, 9, 1000);
      Log('[DNS] Caught resolve request to player '+HostPlayer);
      Result:=gethostbynameNext('localhost');
      Exit;
      end;
  except
    on E: Exception do
      Log('Unhandled exception in gethostbyname: '+E.Message);
    end;
  Result:=gethostbynameNext(name);
end;

function closesocketCallback(s: TSocket): Integer; stdcall;
var
  LocalIRC: TSocket;
begin
  try
    if (s=IRC) and DoLingering then
      begin
      Log('[DEBUG] Worms closing IRC socket 0x'+IntToHex(s, 0)+', transferring to the lingering');
      LocalIRC:=IRC; IRC:=0;    // StopLingering calls closesocket
      StopLingering;
      LingeringIRC:=LocalIRC;
      StartLingering;
      DoLingering:=False;
      Result:=0;
      Exit;
      end;
    if s=IRC then
      IRC:=0;
    if s=HTTP then
      HTTP:=0;
  except
    on E: Exception do
      Log('Unhandled exception in gethostbyname: '+E.Message);
    end;
  Result:=closesocketNext(s);
end;

// ***************************************************************

{var
  WindowProcNext : function (hWnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
  WindowHandle: THandle;
  SocketMessage: Cardinal;

function WindowProcCallback(hWnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
begin
end;}

function WSAAsyncSelectCallback (s: TSocket; HWindow: HWND; wMsg: u_int; lEvent: Longint): Integer; stdcall;
begin
  Log('WSAAsyncSelect for socket 0x'+IntToHex(s, 0)+'; HWindow=0x'+IntToHex(HWindow, 0)+'; wMsg='+IntToStr(wMsg)+'; lEvent=0x'+IntToHex(lEvent, 8), 2);
  {if(s=IRC)and(WindowHandle<>HWindow)then
    begin
    WindowHandle:=HWindow;
    SocketMessage:=wMsg;
    Log('Hooking WindowProc to intercept socket events...');
    WindowProcNext:=Pointer(SetWindowLong(HWindow, GWL_WNDPROC, Integer(@WindowProcCallback)));
    end;}
  Result:=WSAAsyncSelectNext(s, HWindow, wMsg, lEvent);
end;

// ***************************************************************

begin
  Log('------------------ '+DateTimeToStr(Now)+' ------------------');
  if not FileExists('WormNAT.ini') then
    MessageBox(0, 'Warning: WormNAT.ini not found.'#13#10#13#10+
               'WormNAT reads its settings from WormNAT.ini. '#13#10+
               'Chances are that you didn''t copy over this file from the WormKitModules\WormNAT subfolder.'#13#10+
               'WormNAT will use default values, for now.', 'WormNAT', MB_ICONWARNING);
  InitConfig;
  ReloadConfig;
  HookAPI('wsock32.dll',   'connect',       @connectCallback,       @connectNext);
  HookAPI('wsock32.dll',   'send',          @sendCallback,          @sendNext);
  HookAPI('wsock32.dll',   'recv',          @recvCallback,          @recvNext);
  HookAPI('wsock32.dll',   'ioctlsocket',   @ioctlsocketCallback,   @ioctlsocketNext);
  HookAPI('wsock32.dll',   'gethostbyname', @gethostbynameCallback, @gethostbynameNext);
  HookAPI('wsock32.dll',   'closesocket',   @closesocketCallback,   @closesocketNext);
  HookAPI('wsock32.dll',   'WSAAsyncSelect',@WSAAsyncSelectCallback,@WSAAsyncSelectNext);
end.

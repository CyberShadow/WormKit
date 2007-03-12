library wkWormNAT;

{$IMAGEBASE $5a800000}

uses 
  ShareMem, 
  Windows, WinSock, SysUtils, Classes, IniFiles, 
  Packets, PacketsDLL,
  Base, Data, 
  IRCModule, SOCKSModule, MWNModule, Listener, LingerIRC;

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

function ProcessIRCin(Connection: PConnection; var Data: string): Boolean;
var 
  S, From, NoticeMarker: string;
  I: Integer;
begin
  // process Data
  {if Pos(':End of /LIST', Data)<>0 then
    begin
    //S:=Copy(Data, 1, Pos(':End of /LIST', Data)-1) + '#NonExistingChannel 31337 :';
    S:=':wormnet1.team17.com 322 '+Nick+' #NonExistingChannel 31337 :';
    Result:=Result + S + #13#10;
    Log('>> '+S);
    end;}
  if(Pos('[WormNATRouteOn:', Data)<>0)and(MWNPort=0) then
    begin
    S:=Copy(Data, Pos('[WormNATRouteOn:', Data)+16, 1000);
    S:=Copy(S, 1, Pos(']', S)-1);
    MWNPort:=StrToIntDef(S, 0);
    Mode:='MWN';
    Log('Switched to MyWormNet mode, port '+IntToStr(MWNPort));
    end;
  if(Pos('[WormNATRouteOn:', Data)<>0)and(MWNPort=0) then
    begin
    S:=Copy(Data, Pos('[WormNATRouteOn:', Data)+16, 1000);
    S:=Copy(S, 1, Pos(']', S)-1);
    MWNPort:=StrToIntDef(S, 0);
    Mode:='MWN';
    Log('Switched to MyWormNet mode, port '+IntToStr(MWNPort));
    end;
  if Pos(NoticeMarker, Data)<>0 then
    begin
    S:=Data;
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
          if IRC<>nil then
            send(IRC.Socket, S[1], Length(S), 0);
          end;

        S:='NOTICE '+From+' :PARAMEND'+#13#10;
        if LingeringIRC<>0 then
          LingeringSendLn(S, '')
        else
        if IRC<>nil then
          send(IRC.Socket, S[1], Length(S), 0);

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
  Log('[<<<]'+Data, 2);
  Result:=True;
end;

function ProcessIRCout(Connection: PConnection; var Data: string): Boolean;
var 
  S: string;
begin
  // process Data
  if Copy(Data, 1, 5)='NICK ' then
    begin
    if Pos(IRCSuffix, Data)<>0 then
      begin
      IRC:=nil;
      Log('[ONOES] CAPTURED OWN CONNECTION');
      end
    else
      if NickOverride='' then
        begin
        Nick:=Copy(Data, 6, Length(Data)-6);
        Log('[DEBUG] Nick='+Nick, 1);
        end
      else
        begin
        Data:='NICK '+NickOverride;
        Nick:=NickOverride;
        Log('[DEBUG] NickOverride='+Nick, 1);
        end;
    end;
  if Copy(Data, 1, 5)='USER ' then
    begin
    Location:=Copy(Data, Length(Data)-3, 3);
    Log('[DEBUG] Location='+Location, 1);
    if LameHacks then
      begin
      S:=Copy(Data, 1, Pos(':', Data));
      Delete(Data, 1, Pos(':', Data));
      S:=S+Copy(Data, 1, Pos(' ', Data));
      Delete(Data, 1, Pos(' ', Data));
      S:=S+'11 ';
      Delete(Data, 1, Pos(' ', Data));
      S:=S+Data;
      Data:=S;
      end;
    end;
  if Copy(Data, 1, 5)='PASS ' then
    begin
    WormNETPassword:=Copy(Data, 6, Length(Data)-5);
    Log('[DEBUG] WormNETPassword='+WormNETPassword, 1);
    end;
  if UpperCase(Copy(Data, 1, 8))='PRIVMSG ' then
    begin
    if LameHacks then
      Insert(#3'4', Data, Pos(':', Data)+1);
    end;
  if Copy(Data, 1, 4)='QUIT' then
    //if LingeringIRC=0 then
      Data:='';
  Log('[>>>]'+Data, 2);
  Result:=Data<>'';
end;

function ProcessHTTPin(Connection: PConnection; var Data: string): Boolean;
var 
  GameName, Player, Address, Tail: string;
begin
  // process Data
  if (Copy(Data, 1, 6)='<GAME ') and (Pos(' '+InfoURL+' ', Data)<>0) then
    begin
    Delete(Data, 1, 6);
    GameName:=Copy(Data, 1, Pos(' ', Data)-1); Delete(Data, 1, Pos(' ', Data));
    Player  :=Copy(Data, 1, Pos(' ', Data)-1); Delete(Data, 1, Pos(' ', Data));
    Address :=Copy(Data, 1, Pos(' ', Data)-1); Delete(Data, 1, Pos(' ', Data));
    Tail:=Data;

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

    Data:='<GAME '+GameName+' '+Player+' '+Address+' '+Tail;
    end;
  Result:=True;
end;

function ProcessHTTPout(Connection: PConnection; var Data: string): Boolean;
var 
  P: Integer; C: Integer;
begin
  Result:=True;
  // process Data
  if Copy(Data, 1, 4)='GET ' then
    try
      Log('[WWW] '+Data, 1);
      // GET Http://wormnet1.team17.com:80/wormageddonweb/Game.asp?Cmd=Create&Name=ßCyberShadow-MD&HostIP=http://wormnat.xeon.cc/&Nick=CyberShadow-MD&Chan=AnythingGoes&Loc=40&Type=0 HTTP/1.0
      if (Pos('/Game.asp?Cmd=Create&', Data)<>0) and (Pos('HostIP=', Data)<>0) and Server then
        begin
        P:=Pos('Name=',Data) + 5;
        MyGameName:=Data; Delete(MyGameName, 1, P-1); MyGameName:=Copy(MyGameName, 1, Pos('&', MyGameName)-1);
        if(Pos(Nick, MyGameName)<>0)and(Length(MyGameName)-Length(Nick)<3)then
          begin
          MyRealGameName:=MyGameName;
          Delete(Data, P, Length(MyGameName));
          Insert(InfoURL, Data, P);
          MyGameName:=InfoURL;
          end;{}
        P:=Pos('HostIP=', Data) + 7;
        MyRealHost:=Data; Delete(MyRealHost, 1, P-1); MyRealHost:=Copy(MyRealHost, 1, Pos('&', MyRealHost)-1);
        Delete(Data, P, Length(MyRealHost));
        Insert(FakeAddress, Data, P);
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
      if (Pos('/Game.asp?Cmd=Close&', Data)<>0) and (Pos('HostIP=', Data)<>0) and Server then	
        begin
        P:=Pos('Name=',Data) + 5;
        MyGameName:=Data; Delete(MyGameName, 1, P-1); MyGameName:=Copy(MyGameName, 1, Pos('&', MyGameName)-1);
        {if(Pos(Nick, MyGameName)<>0)and(Length(MyGameName)-Length(Nick)<3)then
          begin
          Delete(Data, P, Length(MyGameName));
          Insert(InfoURL, Data, P);
          MyGameName:=InfoURL;
          end;}
        P:=Pos('HostIP=', Data) + 7;
        MyRealHost:=Data; Delete(MyRealHost, 1, P-1); MyRealHost:=Copy(MyRealHost, 1, Pos('&', MyRealHost)-1);
        Delete(Data, P, Length(MyRealHost));
        Insert(FakeAddress, Data, P);
        Log('Game close: '+MyRealHost+' substituted with '+InfoURL);
        end;

      except
        on E: Exception do 
          begin
          //Data:=''; HTTPout:=''; Result:='';
          Log('[HTTP] Error in processing GET request: '+E.Message);
          //HTTPin:='';
          //HTTPin2:='HTTP/1.0 200 OK'#13#10'Error: : '+E.Message+#13#10#13#10+'Error: '+E.Message+#13#10;
          
          Exit;
          end;
        end;
end;

// ***************************************************************

procedure OnBeforeConnect(Connection: PConnection);
var
  Data: string; C: Integer;
begin
  with Connection^ do
    try
      if (AddressLen>=8)and not NoCapture then
        case ConnectionType of
          ctIRC:
            begin
            //Log('IRC socket = 0x'+IntToHex(Socket, 0), 2);
            with Address.sin_addr.S_un_b do
              Log('IRC connect to '+inet_ntoa(Address.sin_addr)+':'+IntToStr(ntohs(Address.sin_port))+', socket=0x'+IntToHex(Socket, 0), 1);
            IRC:=Connection;
            StopLingering;
            StartListener;
            WormNetServer:=inet_ntoa(Address.sin_addr);
            MWNPort:=0;
            //Log('Caught IRC');
            end;
          ctHTTP:
            begin
            //Log('HTTP socket = 0x'+IntToHex(Socket, 0), 2);
            Log('HTTP connect to '+inet_ntoa(Address.sin_addr)+':'+IntToStr(ntohs(Address.sin_port))+', socket=0x'+IntToHex(Socket, 0), 1);
            //Log('Caught HTTP');
            end;
          ctGame:
            begin
            //Log('Game socket = 0x'+IntToHex(Socket, 0), 2);
            with Address.sin_addr.S_un_b do
              Log('GAME connect to '+inet_ntoa(Address.sin_addr)+':'+IntToStr(ntohs(Address.sin_port))+', socket=0x'+IntToHex(Socket, 0), 1);
            DoLingering:=False;
            if inet_ntoa(Address.sin_addr)='127.0.0.1' then
              begin
              if HostPlayer='' then
                Log('[WTF] Unexpected localhost connection')
              else
              if IRC=nil then
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
                send(IRC.Socket, Data[1], Length(Data), 0);
                ParamIdleTime:=0;
                Log('Waiting for parameters...', 1);
                repeat
                  Sleep(10); Inc(ParamIdleTime); 
                  if ParamIdleTime>=1000 then
                    begin
                    Log('Time-out while receiving parameters.');
                    GettingParams:=False;
                    Address.sin_addr.s_addr:=0;
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
                    Address.sin_addr.s_addr:=0;
                    Exit;
                    end;
                until (ActiveModule<>nil)and(ActiveModule.Ready or ActiveModule.Finished);
                if ActiveModule.Ready then
                  begin
                  Log('Module is ready, redirecting connection.');
                  Address.sin_port := htons( LoopbackPort );
                  end
                else
                  begin
                  Log('Module failed to initialize, aborting.');
                  Address.sin_addr.s_addr:=0;
                  Exit;
                  end;
                end;
              end;
            end;
          end;
    except
      on E: Exception do
        Log('Unhandled exception in connect: '+E.Message);
      end;
end;

// ***************************************************************

function makestr(var Data; len: Integer) : string;
begin
  SetLength(Result, len);
  Move(Data, Result[1], len);
end;

procedure OnResolve(Name: PChar; var Host: PHostEnt);
begin
  try
    if Copy(Name, 1, 8)='WormNAT:' then
      begin
      HostPlayer:=Copy(Name, 9, 1000);
      Log('[DNS] Caught resolve request to player '+HostPlayer);
      Host:=gethostbyname('localhost');
      Exit;
      end;
  except
    on E: Exception do
      Log('Unhandled exception in OnResolve: '+E.Message);
    end;
end;

function OnBeforeDisconnect(Connection: PConnection): Boolean;
var
  LocalIRC: TSocket;
begin
  try
    if (Connection=IRC) and DoLingering then
      begin
      Log('[DEBUG] Disconnect on IRC socket 0x'+IntToHex(Connection.Socket, 0)+', transferring to the lingering');
      LocalIRC:=Connection.Socket; IRC:=nil;    // StopLingering calls closesocket
      StopLingering;
      LingeringIRC:=LocalIRC;
      StartLingering;
      DoLingering:=False;
      Result:=False;
      Exit;
      end;
  except
    on E: Exception do
      Log('Unhandled exception in gethostbyname: '+E.Message);
    end;
  Result:=True;
end;

procedure OnDisconnect(Connection: PConnection; Reason: string);
begin
  if Connection=IRC then
    IRC:=nil;
end;

begin
  Log('------------------ '+DateTimeToStr(Now)+' ------------------');
  if not FileExists('WormNAT.ini') then
    MessageBox(0, 'Warning: WormNAT.ini not found.'#13#10#13#10+
               'WormNAT reads its settings from WormNAT.ini. '#13#10+
               'Chances are that you didn''t copy over this file from the WormKitModules\WormNAT subfolder.'#13#10+
               'WormNAT will use default values, for now.', 'WormNAT', MB_ICONWARNING);
  InitConfig;
  ReloadConfig;

  SubscribeToBeforeConnect(OnBeforeConnect);
  SubscribeToIRC(ProcessIRCin, ProcessIRCout);
  SubscribeToHTTP(ProcessHTTPin, ProcessHTTPout);
  SubscribeToResolve(OnResolve);
  SubscribeToBeforeDisconnect(OnBeforeDisconnect);
  SubscribeToDisconnect(OnDisconnect);
end.

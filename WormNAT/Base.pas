unit Base;  // base inter-connectivity prototype, and global vars

interface
uses
  WinSock, Windows, SysUtils, Classes, Packets;

// global options
var     
  LoopbackPort: Word;
  Server: Boolean;
  Mode: string;
  NickOverride: string;
  LogLevel: Integer;
  LameHacks: Boolean;

var
  IRC: PConnection;

// global vars
var
  Nick, Location: string;
  DoLingering: Boolean;
  WormNetServer: string;
  HostPlayer: string;
  NoCapture: Boolean;

type
  TModule = class;
  TLink = class                       // represents link from WormNAT to Worms
    Nickname: string;
    Socket: TSocket;
    Owner: TModule;
    constructor Create(AOwner: TModule; ANickname: string; ASocket: TSocket); 
    procedure CheckForData;
    procedure Write(S: string); 
    end;

  TModule = class                     // represents link from WormNAT to world
    Links: array of TLink;
    Stop: Boolean;
    Ready, Finished: Boolean;
    constructor Create; virtual;
    destructor Destroy; override;
    procedure Main; virtual; abstract;
    procedure Write(From: TLink; S: string); virtual; abstract;
    procedure OnDisconnect(From: TLink); virtual; abstract;
    function AddLink(APlayer: string; ASocket: TSocket): TLink; virtual;
    function PerUserConfig(IP, NickName: string): string; virtual;
    function GetLinkTo(Index: string): TLink;
    property LinkTo[Index: string]: TLink read GetLinkTo; default;
    end;

var
  ActiveModule: TModule;

procedure Log(S: string; Level: Integer = 0);
procedure AppendTo(FN, S: string);

implementation
uses
  LingerIRC;

constructor TLink.Create(AOwner: TModule; ANickname: string; ASocket: TSocket); 
begin
  Owner:=AOwner;
  Nickname:=ANickname;
  Socket:=ASocket;
end;

procedure TLink.CheckForData;
var
  Bytes: u_long; 
  R: Integer;
  Data: string;
  ReadSet: record
    count: u_int;
    Socket: TSocket;
    end;
  TimeVal: TTimeVal;
begin
  if Socket<>0 then
   repeat
    TimeVal.tv_sec:=0;
    TimeVal.tv_usec:=0;

    ReadSet.count:=1;
    ReadSet.Socket:=Socket;
    R:=select(0, @ReadSet, nil, nil, @TimeVal);
    if R=SOCKET_ERROR then
      begin
      Socket:=0;
      Log('[LINK] Link to '+NickName+': select() error ('+IntToStr(WSAGetLastError)+').');
      Owner.OnDisconnect(Self);
      Break;
      end;

    if (ReadSet.count=0)or(R=0) then
      Break;         // nothing to read

    R := ioctlsocket(Socket, FIONREAD, Bytes);
    if R=SOCKET_ERROR then
      begin
      Socket:=0;
      Log('[LINK] Link to '+NickName+' terminated with error '+IntToStr(WSAGetLastError));
      Owner.OnDisconnect(Self);
      Break;
      end;

    if Bytes=0 then 
      begin
      Socket:=0;
      Log('[LINK] Link to '+NickName+' closed gracefully.');
      Owner.OnDisconnect(Self);
      Break;
      end;

    SetLength(Data, Bytes);
    Bytes := recv(Socket, Data[1], Bytes, 0);
    if Bytes=0 then            // huh?
      begin
      Socket:=0;
      Log('[LINK] Link to '+NickName+' closed gracefully.');
      Owner.OnDisconnect(Self);
      Break;
      end;
    if Bytes=SOCKET_ERROR then 
      begin
      Socket:=0;
      Log('[LINK] Link to '+NickName+' terminated with error '+IntToStr(WSAGetLastError));
      Owner.OnDisconnect(Self);
      Break;
      end;
    SetLength(Data, Bytes);
    Owner.Write(Self, Data);
   until False;
end;

procedure TLink.Write(S: string); 
begin
  if Length(S)>0 then
    if send(Socket, S[1], Length(S), 0)=Length(S) then
      Log(' [LINK] Sent '+IntToStr(Length(S))+' bytes.', 2)
    else
      Log(' [LINK] Failed to send binary stream ('+IntToStr(WSAGetLastError)+'): "'+S+'"');
end;

constructor TModule.Create;
begin
  inherited;
  SetLength(Links, 0);
  Stop:=False;
  Ready:=False;
  Finished:=False;
end;

destructor TModule.Destroy;
var
  I: Integer;
begin
  for I:=0 to Length(Links)-1 do
    begin
    if Links[I].Socket<>0 then
      begin
      Log('[LINK] Closing link to '+Links[I].Nickname);
      closesocket(Links[I].Socket);
      end;
    Links[I].Free;
    end;
  SetLength(Links, 0);
  inherited;
end;

function TModule.AddLink(APlayer: string; ASocket: TSocket): TLink;
begin
  Result:=TLink.Create(Self, APlayer, ASocket);
  Log('[LINK] Adding link: '+APlayer);
  SetLength(Links, Length(Links)+1);
  Links[Length(Links)-1]:=Result;
end;

function TModule.GetLinkTo(Index: string): TLink;
var
  I: Integer;
begin
  Result:=nil;
  for I:=0 to Length(Links) do
    if Links[I].Nickname=Index then
      Result:=Links[I];
end;

function TModule.PerUserConfig(IP, Nickname: string): string;
begin
  Result:='';
end;

// ***************************************************************

procedure Log(S: string; Level: Integer = 0);
var
  F: text;
  S2: string;
begin
  // logging to disk will work only if the file WormNAT.log exists
  if Copy(S, 1, 1)<>'-' then
    S:='['+TimeToStr(Now)+'] '+S;

  if LogLevel>=Level then
    begin
    {$I-}
    Assign(F, ExtractFilePath(ParamStr(0))+'WormNAT.log');
    Append(F);
    WriteLn(F, S);
    Close(f);
    {$I+}
    if IOResult<>0 then ;
    end;

  // echo to IRC non-verbose messages
  if Level=0 then
    {if(IRC or LingeringIRC<>0)and(Nick<>'') then
      begin
      S2:=':WormNAT!WormNAT@wormnat.xeon.cc NOTICE '+Nick+' :'+S+#13#10;
      IRCin2:=IRCin2+S2;
      end;}
    if IRC<>nil then
      begin
      S2:=':WormNAT!WormNAT@wormnat.xeon.cc NOTICE '+Nick+' :'+S+#13#10;
      IRC.ReadBufferOut:=IRC.ReadBufferOut+S2;
      IRC.NewReadData:=True;
      end;
end;

procedure AppendTo(FN, S: string);
var
  F: text;
begin
  {$I-}
  Assign(F, ExtractFilePath(ParamStr(0))+FN);
  Append(F);
  Write(F, S);
  Close(f);
  {$I+}
  if IOResult<>0 then ;
end;

end.

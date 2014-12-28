library wkIrcProxy;

{$IMAGEBASE $5ED00000}

uses 
  Windows, WinSock,
  madCHook;

const
  WormNETAddress = 'wormnet1.team17.com';
  WormNETPort = 6667;
  ProxyAddress = 'ircproxy.worms2d.info';
  ProxyPort = 9667;
//  ProxyAddress = 'wormnet1.team17.com';
//  ProxyPort = 6667;

// ***************************************************************

var
  connectNext: function (s: TSocket; name: PSockAddrIn; NameLen: Integer) : Integer; stdcall;
  WormNETHost: PHostEnt = nil;
  ProxyAddr: TSockAddrIn;
  ProxyHost: PHostEnt = nil;

function connectCallback(s: TSocket; name: PSockAddrIn; NameLen: Integer) : Integer; stdcall;
begin
  if (name.sin_family = AF_INET) and (ntohs(name.sin_port) = WormNETPort) then
  begin
    if WormNETHost=nil then
      WormNETHost := gethostbyname(PChar(WormNETAddress));
    if (WormNETHost<>nil) and (name.sin_addr.s_addr = PInAddr(WormNETHost.h_addr_list^).s_addr) then
    begin
      if ProxyHost=nil then
        ProxyHost := gethostbyname(PChar(ProxyAddress));
      if ProxyHost<>nil then
      begin
        name := @ProxyAddr;
        name.sin_family := AF_INET;
        name.sin_addr.s_addr := PInAddr(ProxyHost.h_addr_list^).s_addr;
        name.sin_port := htons(ProxyPort);
      end;
    end;
  end;
  Result := connectNext(s, name, NameLen);
end;

begin
  if not HookAPI('wsock32.dll', 'connect', @connectCallback, @connectNext) then
  begin
    MessageBox(0, 'wkIrcProxy initialization error', 'Error', MB_ICONERROR);
    ExitProcess(1);
  end;
end.

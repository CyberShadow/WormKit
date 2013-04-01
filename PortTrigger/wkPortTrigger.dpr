library wkPortTrigger;

uses
  Windows, WinSock, madCHook;

// ***************************************************************

const
  ServerAddress = 'proxy.worms2d.info';
  ServerPort = 17018;

procedure ThreadProc(Dummy: Pointer); stdcall;
var
  ServerSocket: TSocket;
  ServerAddr: TSockAddrIn;
  ServerHost: PHostEnt;
begin
  ServerSocket := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

  ServerAddr.sin_family := AF_INET;
  ServerHost := gethostbyname(PChar(ServerAddress));
  if ServerHost=nil then
    Exit;
  ServerAddr.sin_addr.s_addr := PInAddr(ServerHost.h_addr_list^).s_addr;
  ServerAddr.sin_port := htons( ServerPort );

  if connect(ServerSocket, ServerAddr, sizeof(ServerAddr))=SOCKET_ERROR then
    Exit;

  closesocket(ServerSocket);
end;

// ***************************************************************

var
  listenNext: function(s: TSocket; backlog: Integer): Integer; stdcall;

// ***************************************************************

function listenCallback(s: TSocket; backlog: Integer): Integer; stdcall;
var
  ThreadID: DWORD;
begin
  Result := listenNext(s, backlog);
  if Result=0 then
    CreateThread(nil, 0, @ThreadProc, nil, 0, ThreadID);
end;

// ***************************************************************

begin
  HookAPI('wsock32.dll', 'listen', @listenCallback, @listenNext);
end.

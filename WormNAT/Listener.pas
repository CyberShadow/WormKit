unit Listener;  // listen to redirected connections on a port, and redirect them through a back-end module

interface
uses
  WinSock, Windows, SysUtils, Base;

procedure StartListener;

implementation

procedure ListenerProc(Nothing: Pointer); stdcall;
var
  m_socket, AcceptSocket: TSocket;
  service: TSockAddrIn;
begin
  NoCapture := True;
  m_socket := socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );

  service.sin_family := AF_INET;
  service.sin_addr.s_addr := inet_addr( '127.0.0.1' );
  service.sin_port := htons( LoopbackPort );

  if bind(m_socket, service, sizeof(service))=SOCKET_ERROR then
    begin
    Log('[LSN] bind error ('+IntToStr(WSAGetLastError)+').');
    NoCapture:=False;
    Exit;
    end;
  
  if listen( m_socket, 1 )=SOCKET_ERROR then
    begin
    Log('[LSN] bind error ('+IntToStr(WSAGetLastError)+').');
    NoCapture:=False;
    Exit;
    end;

  NoCapture := False;
  Log('[LSN] Listener ready on port '+IntToStr(LoopbackPort)+'.');

  repeat
    AcceptSocket := accept( m_socket, nil, nil );
    if AcceptSocket<>INVALID_SOCKET then
      if HostPlayer='' then
        Log('[LSN] Unexpected connection (Host player not set)')
      else
      if ActiveModule=nil then
        Log('[LSN] Unexpected connection (No active module)')
      else
      if not ActiveModule.Ready then
        Log('[LSN] Unexpected connection (Active module not ready)')
      else
        begin
        Log('[LSN] Catching connect to '+HostPlayer);
        ActiveModule.AddLink(HostPlayer, AcceptSocket);
        end
    else
      Sleep(5);
  until False;
end;

var 
  ThreadID: Cardinal = 0;

procedure StartListener;
begin
  if ThreadID=0 then  // start only once
    CreateThread(nil, 0, @ListenerProc, nil, 0, ThreadID);
end;

end.

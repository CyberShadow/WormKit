unit Packets; 
// common type-declaration unit

interface
uses
  ShareMem, Windows, WinSock;

type
  TConnectionType = (ctUnknown, ctHTTP, ctIRC, ctGame, ctOther);
  TDirection = (dIncoming, dOutgoing);
  TConnectionPhase = (cpConnect, cpLobby, cpGame);

  PConnection = ^TConnection;
  TConnectionArray = array of PConnection;

  TConnectSubscriptionProc    = procedure(Connection: PConnection);
  TDisconnectSubscriptionProc = procedure(Connection: PConnection; Reason: string);
  TBeforeDisconnectSubscriptionProc = function(Connection: PConnection): Boolean;
  TRawSubscriptionProc        = procedure(Connection: PConnection; var PacketData: string; Direction: TDirection);
  TPacketSubscriptionProc     = procedure(Connection: PConnection; var PacketData: string; 
                                  var X1, X2: Byte; Direction: TDirection);
  TLobbySubscriptionProc      = procedure(Connection: PConnection; var PacketData: string; 
                                  var X1, X2: Byte; var PacketCommand: Word; Direction: TDirection);
  {TGameSubscriptionProc       = procedure(Connection: PConnection; var PacketData: string; 
                                  var X1, X2, PlayerIndex, PacketIndex: Byte; var X3, X4: Word; 
     broken                       var PacketCommand: Byte; Direction: TDirection);}
  TTextSubscriptionProc       = function(Connection: PConnection; var Data: string): Boolean;
  TResolveSubscriptionProc    = procedure(Name: PChar; var Host: PHostEnt);

  TConnection = packed record
    ConnectionType: TConnectionType;
    Socket: TSocket;
    Direction: TDirection;
    Phase: TConnectionPhase;
    Address: TSockAddrIn;
    AddressLen: Integer;
    PlayerName: string;
    ThreadHandle: THandle; 
    ThreadID: Cardinal;
    //PacketIndex: Byte;
    ReadBufferIn, ReadBufferOut, WriteBufferIn, WriteBufferOut: string;
    NewReadData: Boolean;
    Done: Boolean;
  end;

// lobby packets
const
  lpChat                  = $0000;
  lpIntroduction1         = $0004;
  lpIntroduction2         = $0005;
  lpIntroduction1Ack      = $0008;
  lpExistingPlayers       = $000B;
  lpExistingTeam          = $000C;
  lpPlayerEnters          = $000E;
  lpLightBulb             = $000F;
  lpNewTeam               = $001A;
  lpStartGame1            = $001C;
  lpStartGame2            = $1003;

{
// game packets
const
  gpGameEnd               = $06;
  gpChat                  = $0F;
}

implementation

end.
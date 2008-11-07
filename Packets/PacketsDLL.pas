unit PacketsDLL;
// DLL interface for other modules

interface

uses
  Windows, WinSock, Packets;

const
  wkPackets = 'wkPackets.dll';

procedure SubscribeToBeforeConnect(P: TConnectSubscriptionProc); external wkPackets;
procedure SubscribeToConnect(P: TConnectSubscriptionProc); external wkPackets;
procedure SubscribeToBeforeDisconnect(P: TBeforeDisconnectSubscriptionProc); external wkPackets;
procedure SubscribeToDisconnect(P: TDisconnectSubscriptionProc); external wkPackets;
procedure SubscribeToRaw(P: TRawSubscriptionProc); external wkPackets;
procedure SubscribeToPackets(P: TPacketSubscriptionProc); external wkPackets;
procedure SubscribeToLobby(P: TLobbySubscriptionProc); external wkPackets;
//procedure SubscribeToGame(P: TGameSubscriptionProc); external wkPackets;

procedure SubscribeToIRC(PIn, POut: TTextSubscriptionProc); external wkPackets;
procedure SubscribeToHTTP(PIn, POut: TTextSubscriptionProc); external wkPackets;
procedure SubscribeToOther(P: TRawSubscriptionProc); external wkPackets;

procedure SubscribeToResolve(P: TResolveSubscriptionProc); external wkPackets;

function CreatePacket(Data: string; X1: Byte=0; X2: Byte=0): string; external wkPackets;
function CreateLobbyPacket(PacketCommand: Word; Data: string=''; X1: Byte=0; X2: Byte=0): string; external wkPackets;
//function CreateGamePacket(PacketCommand: Byte; Data: string=''; PlayerIndex: Byte=0; PacketIndex: Byte=0; X3: Word=0; X4: Word=0; X1: Byte=0; X2: Byte=0): string; external wkPackets;
//function CreateGameChatAnonPacket(Text: string): string; external wkPackets;

procedure DisableHooks; external wkPackets;
procedure ReenableHooks; external wkPackets;

function GetConnections: TConnectionArray; external wkPackets;
function IsPacketsInitialized: Boolean; external wkPackets;

implementation

end.
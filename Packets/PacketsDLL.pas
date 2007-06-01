unit PacketsDLL;
// DLL interface for other modules

interface

uses
  Windows, WinSock, Packets;

procedure SubscribeToBeforeConnect(P: TConnectSubscriptionProc); external 'wkPackets.dll';
procedure SubscribeToConnect(P: TConnectSubscriptionProc); external 'wkPackets.dll';
procedure SubscribeToBeforeDisconnect(P: TBeforeDisconnectSubscriptionProc); external 'wkPackets.dll';
procedure SubscribeToDisconnect(P: TDisconnectSubscriptionProc); external 'wkPackets.dll';
procedure SubscribeToRaw(P: TRawSubscriptionProc); external 'wkPackets.dll';
procedure SubscribeToPackets(P: TPacketSubscriptionProc); external 'wkPackets.dll';
procedure SubscribeToLobby(P: TLobbySubscriptionProc); external 'wkPackets.dll';
//procedure SubscribeToGame(P: TGameSubscriptionProc); external 'wkPackets.dll';

procedure SubscribeToIRC(PIn, POut: TTextSubscriptionProc); external 'wkPackets.dll';
procedure SubscribeToHTTP(PIn, POut: TTextSubscriptionProc); external 'wkPackets.dll';

procedure SubscribeToResolve(P: TResolveSubscriptionProc); external 'wkPackets.dll';

function CreatePacket(Data: string; X1: Byte=0; X2: Byte=0): string; external 'wkPackets.dll';
function CreateLobbyPacket(PacketCommand: Word; Data: string=''; X1: Byte=0; X2: Byte=0): string; external 'wkPackets.dll';
//function CreateGamePacket(PacketCommand: Byte; Data: string=''; PlayerIndex: Byte=0; PacketIndex: Byte=0; X3: Word=0; X4: Word=0; X1: Byte=0; X2: Byte=0): string; external 'wkPackets.dll';
//function CreateGameChatAnonPacket(Text: string): string; external 'wkPackets.dll';

function GetConnections: TConnectionArray; external 'wkPackets.dll';

implementation

end.
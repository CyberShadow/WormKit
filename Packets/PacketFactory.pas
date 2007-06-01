unit PacketFactory;
// packet creation

interface

uses
  Packets;

function CreatePacket(Data: string; X1: Byte=0; X2: Byte=0): string;
function CreateLobbyPacket(PacketCommand: Word; Data: string=''; X1: Byte=0; X2: Byte=0): string;

{
function CreateGamePacket(PacketCommand: Byte; Data: string=''; PlayerIndex: Byte=0; PacketIndex: Byte=0; X3: Word=0; X4: Word=0; X1: Byte=0; X2: Byte=0): string;
function CreateGameChatAnonPacket(Text: string): string;
}

implementation

function WordToStr(W: Word): string; inline;
begin Result:=Chr(W mod $100)+Chr(W div $100) end;

function CreatePacket(Data: string; X1: Byte=0; X2: Byte=0): string;
begin
  Result:=Chr(X1)+Chr(X2)+WordToStr(Length(Data)+4)+Data;
end;

function CreateLobbyPacket(PacketCommand: Word; Data: string=''; X1: Byte=0; X2: Byte=0): string;
begin
  Result:=CreatePacket(WordToStr(PacketCommand)+Data, X1, X2);
end;

{
function CreateGamePacket(PacketCommand: Byte; Data: string=''; PlayerIndex: Byte=0; PacketIndex: Byte=0; X3: Word=0; X4: Word=0; X1: Byte=0; X2: Byte=0): string;
begin
  Result:=CreatePacket(Chr(PlayerIndex)+Chr(PacketIndex)+WordToStr(X3)+WordToStr(X4)+Chr(PacketCommand)+Data, X1, X2);
end;

function CreateGameChatAnonPacket(Text: string): string;
begin
  Result:=CreateGamePacket($0F, #$FF#$FF+Text+#0#0);
end;
}

end.
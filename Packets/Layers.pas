unit Layers;
// advanced layer provider

interface

uses
  Packets, Main;

implementation

function WordToStr(W: Word): string; inline;
begin Result:=Chr(W mod $100)+Chr(W div $100) end;

procedure MyRawProc(Connection: PConnection; var PacketData: string; Direction: TDirection);
var
  Data: string;
  PacketSize: Word;
  X1, X2: Byte;
  I: Integer;
begin
  if Length(PacketData)<4 then
    Exit;
  Move(PacketData[1], X1, 1);
  Move(PacketData[2], X2, 1);
  Move(PacketData[3], PacketSize, 2);
  if Length(PacketData)<PacketSize then
    Exit;
  Data:=Copy(PacketData, 5, PacketSize-4);
  if Data='' then
    Exit;

  for I:=0 to High(PacketSubscriptions) do
    PacketSubscriptions[I](Connection, Data, X1, X2, Direction);

  if Data='' then
    PacketData:=''
  else
    begin
    PacketSize:=Length(Data)+4;
    PacketData:=Chr(X1)+Chr(X2)+WordToStr(PacketSize)+Data;
    end;
end;

procedure MyPacketProc(Connection: PConnection; var PacketData: string; var X1, X2: Byte; Direction: TDirection);
var
  Data: string;
  PacketCommand{, X3, X4}: Word;
  I: Integer;
  //PlayerIndex, PacketIndex, PacketCommandB: Byte;
begin
  if Connection.Phase=cpLobby then
    begin
    //TLobbySubscriptionProc      = procedure(Connection: PConnection; var PacketData: string; 
    //                                var X1, X2: Byte; var PacketCommand: Word; Direction: TDirection);
    if Length(PacketData)<2 then 
      Exit;
    Move(PacketData[1], PacketCommand, 2);
    Data:=Copy(PacketData, 3, Length(PacketData)-2);

    for I:=0 to High(LobbySubscriptions) do
      LobbySubscriptions[I](Connection, Data, X1, X2, PacketCommand, Direction);

    if(Data='')and(PacketCommand=0) then
      PacketData:=''
    else
      PacketData:=WordToStr(PacketCommand)+Data;
    end
  {
  else    // Game packet
    begin
    //TGameSubscriptionProc      = procedure(Connection: PConnection; var PacketData: string; 
    //                                var X1, X2, PlayerIndex, PacketIndex: Byte; var X3, X4: Word; 
    //                                var PacketCommand: Byte; Direction: TDirection);
    if Length(PacketData)<7 then 
      Exit;
    Move(PacketData[1], PlayerIndex, 1);
    Move(PacketData[2], PacketIndex, 1);
    Move(PacketData[3], X3, 2);
    Move(PacketData[5], X4, 2);
    Move(PacketData[7], PacketCommandB, 1);
    Data:=Copy(PacketData, 8, Length(PacketData)-7);

    if PlayerIndex>8 then
      Exit;   // haven't figured out these packets yet

    for I:=0 to High(GameSubscriptions) do
      GameSubscriptions[I](Connection, Data, X1, X2, PlayerIndex, PacketIndex, X3, X4, PacketCommandB, Direction);

    if(Data='')and(PacketCommandB=0) then
      PacketData:=''
    else
      PacketData:=Chr(PlayerIndex)+Chr(PacketIndex)+WordToStr(X3)+WordToStr(X4)+Chr(PacketCommandB)+Data;
    end;
  }
end;

procedure MyLobbyProc(Connection: PConnection; var PacketData: string; var X1, X2: Byte; var PacketCommand: Word; Direction: TDirection);
var
  S: string;
begin
  case PacketCommand of
    lpIntroduction1:
      if Direction=dIncoming then
        begin
        Connection.PlayerName:=Copy(PacketData, 1, Pos(#0, PacketData)-1);
        end;
    lpExistingPlayers:
      if Direction=dIncoming then
        begin
        S:=Copy(PacketData, 7, Length(PacketData));
        Connection.PlayerName:=Copy(S, 1, Pos(#0, S)-1);
        end;
    lpStartGame2:
      Connection.Phase:=cpGame;
    end;
end;

{
procedure MyGameProc(Connection: PConnection; var PacketData: string; var X1, X2, PlayerIndex, PacketIndex: Byte; var X3, X4: Word; var PacketCommand: Byte; Direction: TDirection);
begin
  case PacketCommand of
    gpGameEnd:
      Connection.Phase:=cpLobby;
    end;
end;
}

begin
  SubscribeToRaw(MyRawProc);
  SubscribeToPackets(MyPacketProc);
  SubscribeToLobby(MyLobbyProc);
  //SubscribeToGame(MyGameProc);
end.
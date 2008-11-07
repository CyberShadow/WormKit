library wkPackets;

{$IMAGEBASE $66800000}

uses
  ShareMem, Main, Layers, PacketFactory;

exports
  SubscribeToBeforeConnect,
  SubscribeToConnect,
  SubscribeToBeforeDisconnect,
  SubscribeToDisconnect,
  SubscribeToRaw,
  SubscribeToPackets,
  SubscribeToLobby,
  //SubscribeToGame,

  SubscribeToIRC,
  SubscribeToHTTP,
  SubscribeToOther,
  
  SubscribeToResolve,

  CreatePacket,
  CreateLobbyPacket,
  //CreateGamePacket,
  //CreateGameChatAnonPacket;

  DisableHooks,
  ReenableHooks,
  
  GetConnections,
  IsPacketsInitialized;

begin
end.

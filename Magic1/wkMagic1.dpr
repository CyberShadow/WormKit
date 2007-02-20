library wkMagic1;

{$IMAGEBASE $6D800000}

// This source code is for demonstrational purposes only, and is not meant to be recompiled.
// I will not respond to requests of providing the source code or binaries of missing units.

// Idea, partial source code (c) NotWorthy
// Most source code (c) The_CyberShadow
// Redistribution outside the initial package, modification, compilation, 
// use for the means of reverse engineering of the binary is prohibited.

uses 
  WA_3_6_26_5, WA_common, FrameHook, GameInitHook, MapBarCode, FMath, Windows, USysUtils{, mmSystem};

const
  InitializationFrameNr = 0;

var
  Initialized: Boolean = False;
  
  Settings: record
    StartX, StartY: Word;
    TeleOnPlop: Boolean;
    RemovedCollisions: Cardinal;         // clWormsOnLand || clWormsOnRopeBungee
    WindFactor: Integer;                 // 0x10000 = 1.0 = 100%
    NoSitters: Boolean;
    MineCount: Integer;
    PhantomWorms: Boolean;
    end;
  
// ***************************************************************

var
  Logged: Boolean;

procedure Log(S: string);
var
  F: Text;
begin
  Assign(F, 'magic.log');
  {$I-}Append(F);{$I+} 
  if IOResult<>0 then
    ReWrite(F); 
  if not Logged then
    begin
    WriteLn(F, '--------------------------------------------------------');
    Logged:=True;
    end;
  WriteLn(F, TimeStr+' '+S);
  Close(F);
end;

procedure MyGameFrameProc;
var
  GameState: PGameState;
  Game: PGame;
  I: Integer;
  W: PGameObject;
  BCS : TBarCodeStream;
  ChunkID, FillByte: Byte;
begin
  GameState:=GetGameState;

  if (GameState=nil) or
     (GameState.Game=nil) or
     (GameState.Game.Environment=nil) or
     (GameState.Game.Environment.Objects.Count<=1) then
    begin                                              
    Initialized := False;
    Exit
    end;

  Game:=GameState.Game;

  if not Initialized and (Game.FrameNr = InitializationFrameNr) then
    begin
    // read data from the map on game start
    //BCS := GetBarCodeStream(Game);
    BCS := FindBarCode(Game, 'wkMagic1');
    {if BCS.BarCode=nil then
      begin
      Initialized := False;
      Exit
      end;}

    if BCS.BarCode<>nil then
      begin
      Log('Barcode signature found, loading map options...');

      FillByte := 0;
      repeat
        if not ReadBarCodeData(BCS, ChunkID, 1) then 
          Break;
        case ChunkID of
           0, $FF: // end of data
            begin
            Log('End of map options.');
            FillByte := ChunkID;
            Break;
            end;
           1: // set starting position
            begin
            Log('* Start position set to ('+IntToStr(Settings.StartX)+', '+IntToStr(Settings.StartY)+')');
            ReadBarCodeData(BCS, Settings.StartX, 2);
            ReadBarCodeData(BCS, Settings.StartY, 2);
            end;
           2: // enable teleport to start position on plop
            begin
            Log('* Anti-sink enabled');
            Settings.TeleOnPlop := True;
            end;
           3: // remove some collisions from worms on ropes
            begin
            Log('* Roping worms collision filter set');
            ReadBarCodeData(BCS, Settings.RemovedCollisions, 4);
            end;
           4: // set factor by which worms are affected by the wind
            begin
            Log('* Worm wind factor set to '+IntToStr(Settings.WindFactor));
            ReadBarCodeData(BCS, Settings.WindFactor, 4);
            end;
           5: // phantom worms - the collision specified in chunk 3 gets applied on all worms at all times
            begin
            Log('* Phantom worms enabled');
            Settings.PhantomWorms := True;
            end;
           else
            Log('Unknown chunk in map barcode ('+IntToStr(ChunkID)+'). Your version of wkMagic1.dll is probably out-of-date.');
          end;
      until False;
      
      ClearBarCode(BCS, FillByte);  // fill the place where the barcode was with empty space/solid stuff
      end;
    Initialized := True;
    end;

  if not Initialized then
    Exit;

  // null Settings parameters must not affect gameplay in any way !

  try
    // process global stuff
    if Game.FrameNr = InitializationFrameNr then    // center camera on start position on first frame
      begin
      if (Settings.StartY<>0)and not Scheme.Data.WormPlacement then
        begin
        Game.CameraX := Settings.StartX * $10000;
        Game.CameraY := Settings.StartY * $10000;
        end;
      end;

    // process individual objects
    for I:=0 to Game.Environment.Objects.Count-1 do
      if Game.Environment.Objects.List[I] <> nil then
       if Game.Environment.Objects.List[I].VMT = TWormObjectVMT then
        begin
        W := Game.Environment.Objects.List[I];
        
        // set WindFactor for worms
        if Settings.WindFactor<>0 then
          begin
          W.WindFactor := Settings.WindFactor;
        
          // WindFactor doesn't affect worms on ropes, so we need to apply wind manually
          if W.RopeAttached then
            W.SpeedX := W.SpeedX + FMultiply(Game.Environment.Wind, Settings.WindFactor);
          end;
          
        if Settings.RemovedCollisions<>0 then
          if W.RopeAttached or Settings.PhantomWorms then
            // make worms on rope pass through other worms
            W.CollisionGroups := W.CollisionGroups and (not Settings.RemovedCollisions)
          else
            // restore normal collision mask
            W.CollisionGroups := W.CollisionGroups or Settings.RemovedCollisions;

        // teleport all worms to start position
        if Game.FrameNr = InitializationFrameNr then
         if (Settings.StartY<>0) and not Scheme.Data.WormPlacement then
          begin
          W.X:=Settings.StartX * $10000;
          W.Y:=Settings.StartY * $10000;
          W.SpeedX := 0;
          W.SpeedY := 0;
          W.Direction := -1;
          W.ObjectState := osAiming;
          end;

        // check for plop
        if (W.Y + W.SpeedY + Game.Environment.Gravity >= Game.Environment.WaterLevel * $10000) and (Game.FrameNr > InitializationFrameNr) then
         if Settings.StartY<>0 then
          begin
          W.X := Settings.StartX * $10000;
          W.Y := Settings.StartY * $10000;
          W.SpeedX := 0;
          W.SpeedY := 0;
          W.RopeAttached := False;
          W.ObjectState := osAiming;
          Game.CameraX := Settings.StartX * $10000;
          Game.CameraY := Settings.StartY * $10000;
          // this method of playing a sound doesn't respect W:A's volume setting
          //sndPlaySound('DATA\Wav\Effects\wormpop.wav', SND_ASYNC or SND_NODEFAULT);
          end;
        end
       else
       if Game.Environment.Objects.List[I].VMT = TProjectileObjectVMT then
        begin
        W := Game.Environment.Objects.List[I];
        if Settings.NoSitters then
          if (W.SpeedX=0)and(W.SpeedY=0) then
            begin
            if W.ProjectileExplosionRadius<>-10 then
              begin
              W.ProjectileExplosionRadius  := -10;
              //Log('ProjectileExplosionRadius set');
              end;
            if W.ProjectileExplosionRadius2<>-10 then
              begin
              W.ProjectileExplosionRadius2 := -10;
              //Log('ProjectileExplosionRadius2 set');
              end;
            end;
        end;
  except
    end;
end;

procedure MyBeforeGameInitProc;
begin
  Initialized := False;
  FillChar(Settings, SizeOf(Settings), 0);
  
  //Log('Grenade power='+IntToStr(Scheme.Data.WeaponSettings[wGrenade].Power));
  if Scheme.Data.WeaponSettings[wGrenade].Power in [200..204] then
    begin
    Dec(Scheme.Data.WeaponSettings[wGrenade].Power, 200);
    Settings.NoSitters := True;
    Log('Scheme option: anti-sitter enabled');
    end;

  //Log('Mine power='+IntToStr(Scheme.Data.WeaponSettings[wMine].Power));
  if Scheme.Data.WeaponSettings[wMine].Power in [200..230] then
    begin
    Settings.MineCount := Scheme.Data.WeaponSettings[wMine].Power - 200;
    Scheme.Data.WeaponSettings[wMine].Power := 2;
    end;
end;

procedure MyAfterGameInitProc;
begin
  if Settings.MineCount <> 0 then
    begin
    GameOptions.MineBarrelCount := Settings.MineCount;
    Log('Scheme option: number of mines set to '+IntToStr(Settings.MineCount));
    end;
end;

// ***************************************************************

begin
  GameFrameProc := MyGameFrameProc;
  GameBeforeInitProc := MyBeforeGameInitProc;
  GameAfterInitProc := MyAfterGameInitProc;
  AutoCheckFrameHooks;
  AutoCheckInitHooks;
end.

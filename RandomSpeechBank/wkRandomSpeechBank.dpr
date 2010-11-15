library wkRandomSpeechBank;

{$IMAGEBASE $62800000}

uses Windows, USysUtils, madCodeHook;

var 
  CreateFileANext : function(lpFileName: PAnsiChar; dwDesiredAccess, dwShareMode: DWORD;
    lpSecurityAttributes: PSecurityAttributes; dwCreationDisposition, dwFlagsAndAttributes: DWORD;
    hTemplateFile: THandle): THandle; stdcall;
  mmioOpenANext : function(pszFileName: PAnsiChar; pmmioInfo: Pointer; fdwOpen: Cardinal): THandle; stdcall;

// ***************************************************************

var
  CDDrive: AnsiChar;
  CurrentBank: Integer;
  LastChange: Cardinal;

const
  Banks: array[0..48] of string = ('Africaan', 'American', 'Angry Scots', 'Australian', 'Brooklyn', 'Brummie', 'Cad', 'Cyberworms', 'Danish-Pyrus', 'Double-Oh-Seven', 'Drill Sergeant', 'Dutch', 'English', 'Finnish', 'Formula One', 'French', 'Geezer', 'German', 'Goofed', 'Greek', 'Hispanic', 'Hungarian', 'Irish', 'Italian', 'Jock', 'Kamikaze', 'Kidz', 'Norwegian', 'Polish', 'Portuguese', 'Rasta', 'Redneck', 'Rushki', 'Russian', 'Scouser', 'Smooth Babe', 'Soul Man', 'Spanish', 'Stiff Upper Lip', 'Stooges', 'Swedish', 'Team17 Test', 'The Raj', 'Thespian', 'Tykes', 'US Sports', 'Wacky', 'Whoopsie', 'Wideboy');
  Files: array[0..57] of string = ('amazing.wav', 'boring.wav', 'brilliant.wav', 'bummer.wav', 'bungee.wav', 'byebye.wav', 'collect.wav', 'comeonthen.wav', 'coward.wav', 'dragonpunch.wav', 'drop.wav', 'excellent.wav', 'fatality.wav', 'fire.wav', 'fireball.wav', 'firstblood.wav', 'flawless.wav', 'goaway.wav', 'grenade.wav', 'hello.wav', 'hmm.wav', 'hurry.wav', 'illgetyou.wav', 'incoming.wav', 'jump1.wav', 'jump2.wav', 'justyouwait.wav', 'kamikaze.wav', 'laugh.wav', 'leavemealone.wav', 'missed.wav', 'nooo.wav', 'ohdear.wav', 'oinutter.wav', 'ooff1.wav', 'ooff2.wav', 'ooff3.wav', 'oops.wav', 'orders.wav', 'ouch.wav', 'ow1.wav', 'ow2.wav', 'ow3.wav', 'perfect.wav', 'revenge.wav', 'runaway.wav', 'stupid.wav', 'takecover.wav', 'traitor.wav', 'uh-oh.wav', 'victory.wav', 'walk-compress.wav', 'walk-expand.wav', 'watchthis.wav', 'whatthe.wav', 'wobble.wav', 'yessir.wav', 'youllregretthat.wav');

function AdjustPath(S: AnsiString): AnsiString;
var
  P: Integer;
begin
  //messagebeep(0);
  Result := S;
  P := Pos('\random\', LowerCase(S));
  if P>0 then
  begin
    if GetTickCount-LastChange>10000 then
    begin
      Randomize;
      CurrentBank := Random(Length(Banks));
    end;
    LastChange := GetTickCount;
    Result := CDDrive + ':\Data\User\Speech\' + Banks[CurrentBank] + Copy(S, P+7, 100);
    if not FileExists(Result) then
      Result := CDDrive + ':\Data\User\Speech\English' + Copy(S, P+7, 100);
  end;
end;

// ***************************************************************

function CreateFileACallback(lpFileName: PAnsiChar; dwDesiredAccess, dwShareMode: DWORD;
  lpSecurityAttributes: PSecurityAttributes; dwCreationDisposition, dwFlagsAndAttributes: DWORD;
  hTemplateFile: THandle): THandle; stdcall;
begin
  Result:=CreateFileANext(PAnsiChar(AdjustPath(lpFileName)), dwDesiredAccess, dwShareMode, 
            lpSecurityAttributes, dwCreationDisposition, dwFlagsAndAttributes, 
            hTemplateFile);
end;

function mmioOpenACallback(pszFileName: PAnsiChar; pmmioInfo: Pointer; fdwOpen: Cardinal): THandle; stdcall;
begin
  LastChange := 0;
  Result := mmioOpenANext(PAnsiChar(AdjustPath(pszFileName)), pmmioInfo, fdwOpen);
end;

// ***************************************************************

var
  I: Integer;
  T: Text;

begin
  for CDDrive:='C' to '[' do
    if GetDriveTypeA(PAnsiChar(CDDrive+':\'))=DRIVE_CDROM then
      if DirectoryExists(CDDrive+':\Data\User\Speech') then
        break;
  if CDDrive='[' then
  begin
    MessageBoxA(0, 'Can''t find W:A CD...', 'wkRandomSpeechBank error', MB_ICONERROR);
    Exit;
  end;

  if not DirectoryExists('User\Speech\Random') then
  begin
    ForceDirectories('User\Speech\Random');
    for I:=0 to High(Files) do
    begin
      AssignFile(T, 'User\Speech\Random\'+Files[I]);
      ReWrite(T);
      WriteLn(T, 'This is a placeholder.');
      Close(T);
    end;
  end;
  
  HookAPI('kernel32.dll', 'CreateFileA', @CreateFileACallback, @CreateFileANext);
  HookAPI('winmm.dll', 'mmioOpenA', @mmioOpenACallback, @mmioOpenANext);
end.

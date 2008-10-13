program WormKit;

uses Windows, USysUtils, madCHook;

var 
  si : TStartupInfo;
  pi : TProcessInformation;
  commandLine : string;
  i: Integer;

{$R *.res}

begin
  // just a loader - check if all is OK and launch WA.exe + HookLib.dll

  ChDir(ExtractFilePath(ParamStr(0)));

  if(ParamCount=0)and(not FileExists('WA.exe')) then
    begin
    MessageBox(0, 'You need to unpack WormKit to your Worms : Armageddon folder.', 'Error', MB_ICONERROR);
    Exit;
    end;

  ZeroMemory(@si, sizeOf(si));
  if ParamCount=0 then
    commandLine:=ExpandFileName('WA.exe')+' /nointro'
  else
  if (ParamCount=1) and FileExists(ParamStr(1)) and (LowerCase(ExtractFileExt(ParamStr(1)))='.wagame') then
    commandLine := ExpandFileName('WA.exe')+' /play "' + ParamStr(1) + '"'
  else
    begin
    commandLine:='';
    for i:=1 to ParamCount do
      commandLine:=commandLine+' "'+ParamStr(i)+'"';
    Delete(commandLine, 1, 1);
    end;

  if not CreateProcessEx (nil, PChar(commandLine), nil, nil, false, 0, nil, nil, si, pi, 'HookLib.dll') then
    MessageBox(0, 'Failed to start W:A + WormKit. '#13#10'Check that you have administrator priviledges, and that all DLLs are in place.', 'Error', MB_ICONERROR);
end.

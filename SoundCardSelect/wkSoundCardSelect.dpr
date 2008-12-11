library wkSoundCardSelect;

uses
  Windows, SysUtils, madCHook, DirectSound, ComObj;

{$IMAGEBASE $65800000}

// ***************************************************************

var
  DirectSoundCreateNext: function(lpGuid: PGUID; out ppDS: IDirectSound; pUnkOuter: IUnknown): HResult; stdcall;
  DeviceGuid: TGuid;
  AllDevices: string;

// ***************************************************************

function DirectSoundCreateCallback(lpGuid: PGUID; out ppDS: IDirectSound; pUnkOuter: IUnknown): HResult; stdcall;
begin
  Result := DirectSoundCreateNext(@DeviceGuid, ppDS, pUnkOuter);
end;

// ***************************************************************

function DSEnumCallback(lpGuid: PGUID; lpcstrDescription, lpcstrModule: PAnsiChar; lpContext: Pointer): BOOL; stdcall;
begin
  if lpGuid<>nil then
    AllDevices := AllDevices +
      '   * ' + GuidToString(lpGuid^) + #13#10 +
      '             ' + lpcstrDescription + ' (' + lpcstrModule + ')' + #13#10;
  Result := True;
end;

var
  F: Text;
  S: String;

begin
  try
    if FileExists('WASoundCard.txt.txt') and not FileExists('WASoundCard.txt') then
    begin
      Assign(F, 'WASoundCard.txt.txt'); Rename(F, 'WASoundCard.txt');
      MessageBox(0, 'Your WASoundCard.txt file isn''t named correctly (two extensions), I renamed it to its correct name.', 'wkSoundCardSelect', MB_ICONINFORMATION);
    end;
    if FileExists('WASoundCard') and not FileExists('WASoundCard.txt') then
    begin
      Assign(F, 'WASoundCard'); Rename(F, 'WASoundCard.txt');
      MessageBox(0, 'Your WASoundCard.txt file isn''t named correctly (no extension), I renamed it to its correct name.', 'wkSoundCardSelect', MB_ICONINFORMATION);
    end;
    if FileExists('WASoundCard.txt') then
    begin
      Assign(F, 'WASoundCard.txt');
      Reset(F);
      ReadLn(F, S);
      Close(F);
      if Copy(S, 1, 1)<>'{' then
        S := '{' + S;
      if Copy(S, Length(S), 1)<>'}' then
        S := S + '}';
      DeviceGuid := StringToGuid(S);
      HookAPI('dsound.dll', 'DirectSoundCreate', @DirectSoundCreateCallback, @DirectSoundCreateNext);
    end
    else
    begin
      DirectSoundEnumerate(DSEnumCallback, nil);
      MessageBox(0, PChar(
        'Now that you''ve installed the module, create a text file called "WASoundCard" in your W:A folder'#13#10+
        'and place the GUID (the text between the { }) of the desired sound device in it: '#13#10#13#10+
        AllDevices+#13#10+
        'Tip: to copy the contents of any Windows message box, press Ctrl+C'), 'wkSoundCardSelect', MB_ICONINFORMATION);
      ExitProcess(0);
    end;
  except
    on E: Exception do
    begin
      MessageBox(0, PChar(E.Message), 'wkSoundCardSelect error', MB_ICONERROR);
      ExitProcess(0);
    end;
  end;
end.

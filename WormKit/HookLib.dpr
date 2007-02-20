library HookLib;

{$IMAGEBASE $60800000}

uses Windows;

var
  F: TWin32FindData;
  H, M: THandle;
  Modules: array[1..100] of THandle;
  ModuleNr: Integer;

procedure LibraryProc(Reason: Integer);
var
  I: Integer;
begin
  if Reason = DLL_PROCESS_DETACH then
    begin
    for I:=1 to ModuleNr do
      FreeLibrary(Modules[I]);
    ModuleNr:=0;
    end;
end;

begin
  // locate and load WormKit modules

  H:=FindFirstFile('wk*.dll', F);
  if H=INVALID_HANDLE_VALUE then
    MessageBox(0, 'Warning: no WormKit modules were loaded. '#13#10#13#10+
      'WormKit''s features are provided by modules. '#13#10+
      'To activate certain modules, simply copy the files from the WormKitModules folder.', 'WormKit', MB_ICONWARNING)
  else
    begin
    repeat
      M:=LoadLibrary(F.cFileName);
      if M=0 then
        MessageBox(0, PChar('Warning: can''t load module "'+F.cFileName+'".'#13#10#13#10+
          'It''s probably missing some DLL files it depends on.'), 'WormKit', MB_ICONWARNING)
      else
        begin
        Inc(ModuleNr);
        Modules[ModuleNr]:=M;
        end;
    until not FindNextFile(H, F);
    end;
  FindClose(H);

  DllProc:=@LibraryProc;
end.

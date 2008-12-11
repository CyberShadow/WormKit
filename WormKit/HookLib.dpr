library HookLib;

{$IMAGEBASE $60800000}

uses Windows;

var
  F: TWin32FindData;
  H, M: THandle;
  Modules: array[1..100] of THandle;
  ModuleNr, ErrNo: Integer;
  ErrNoStr: string;
  Msg: PChar;

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

function SysErrorMessage(ErrorCode: Integer): string;
var
  Buffer: array[0..255] of Char;
var
  Len: Integer;
begin
  Len := FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS or
    FORMAT_MESSAGE_ARGUMENT_ARRAY, nil, ErrorCode, 0, Buffer,
    SizeOf(Buffer), nil);
  while (Len > 0) and (Buffer[Len - 1] in [#0..#32, '.']) do Dec(Len);
  SetString(Result, Buffer, Len);
end;

procedure Dummy;
begin
end;

exports
  Dummy;

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
      begin
        ErrNo := GetLastError;
        Str(ErrNo, ErrNoStr);
        {Msg := AllocMem(4096);
        FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM,
                        nil,
                        ErrNo,
                        0,
                        Msg,
                        4096,
                        nil);        
 
        Str(Length(Msg), ErrNoStr);}
        
        MessageBox(0, PChar('Warning: can''t load module "'+F.cFileName+'".'#13#10+
          'It''s probably missing some DLL files it depends on.'#13#10#13#10+
          'Error #'+ErrNoStr+':'#13#10+
          SysErrorMessage(ErrNo)), 'WormKit', MB_ICONWARNING);
        //FreeMem(Msg);
      end
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

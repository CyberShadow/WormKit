library wkFileOverride;

{$IMAGEBASE $62800000}

uses Windows, USysUtils, madCHook, MMSystem;

var 
  CreateFileANext : function(lpFileName: PAnsiChar; dwDesiredAccess, dwShareMode: DWORD;
    lpSecurityAttributes: PSecurityAttributes; dwCreationDisposition, dwFlagsAndAttributes: DWORD;
    hTemplateFile: THandle): THandle; stdcall;
  GetPrivateProfileIntANext : function(lpAppName, lpKeyName: PAnsiChar; nDefault: Integer; lpFileName: PAnsiChar): UINT; stdcall;
  GetPrivateProfileStringANext : function(lpAppName, lpKeyName, lpDefault: PAnsiChar; lpReturnedString: PAnsiChar; nSize: DWORD; lpFileName: PAnsiChar): DWORD; stdcall;
  mmioOpenANext: function(szFileName: PChar; lpmmioinfo: PMMIOInfo; dwOpenFlags: DWORD): HMMIO; stdcall;

// ***************************************************************

procedure Log(S: string);
var
  F: text;
begin
  Assign(F, ExtractFilePath(ParamStr(0))+'FileOverride.log');
  {$I-}
  Append(F);
  {$I+}
  if IOResult<>0 then 
    ReWrite(F);
  WriteLn(F, '['+TimeStr+'] '+S);
  Close(f);
end;

// ***************************************************************

function AdjustPath(S: ansistring): ansistring;
begin
  Result := S;
  if Copy(S, 2, 2)=':\' then // looks like an absolute path
    begin
    //Log('  '+S);
    Delete(S, 1, 3);               // delete the absolute path prefix; "D:\Data\..." becomes "Data\..."
    if (Length(S)=0)or(S[1]='.') then
      // don't do anything
    else  
    if FileExists(S) then
      begin
      //Log('* Overriding '+S);
      Result := S
      end
    else
      begin
      S:='CD\'+S;
      if FileExists(S) then
        begin
        //Log('* Overriding '+S);
        Result := S
        end;
      //else
      // if not FileExists(lpFileName) then
      //  MessageBox(0, lpFileName, nil, 0);
      end;
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

function GetPrivateProfileIntACallback(lpAppName, lpKeyName: PAnsiChar; nDefault: Integer; lpFileName: PAnsiChar): UINT; stdcall;
begin
  if lpFileName=nil then
    Result := GetPrivateProfileIntANext(lpAppName, lpKeyName, nDefault, lpFileName)
  else
    Result := GetPrivateProfileIntANext(lpAppName, lpKeyName, nDefault, PAnsiChar(AdjustPath(lpFileName)));
end;

function GetPrivateProfileStringACallback(lpAppName, lpKeyName, lpDefault: PAnsiChar; lpReturnedString: PAnsiChar; nSize: DWORD; lpFileName: PAnsiChar): DWORD; stdcall;
begin
  if lpFileName=nil then
    Result := GetPrivateProfileStringANext(lpAppName, lpKeyName, lpDefault, lpReturnedString, nSize, lpFileName)
  else
    Result := GetPrivateProfileStringANext(lpAppName, lpKeyName, lpDefault, lpReturnedString, nSize, PAnsiChar(AdjustPath(lpFileName)));
end;

function mmioOpenACallback(szFileName: PChar; lpmmioinfo: PMMIOInfo; dwOpenFlags: DWORD): HMMIO; stdcall;
begin
  Result := mmioOpenANext(PAnsiChar(AdjustPath(szFileName)), lpmmioinfo, dwOpenFlags);
end;

// ***************************************************************

begin
  //Log('---------------');
  HookAPI('kernel32.dll', 'CreateFileA',              @CreateFileACallback,              @CreateFileANext);
  HookAPI('kernel32.dll', 'GetPrivateProfileIntA',    @GetPrivateProfileIntACallback,    @GetPrivateProfileIntANext);
  HookAPI('kernel32.dll', 'GetPrivateProfileStringA', @GetPrivateProfileStringACallback, @GetPrivateProfileStringANext);
  HookAPI('winmm.dll',    'mmioOpenA',                @mmioOpenACallback,                @mmioOpenANext);
end.

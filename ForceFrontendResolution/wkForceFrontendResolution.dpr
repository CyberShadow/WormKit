library wkForceFrontendResolution;

uses
  Windows, madCHook;

function GetInterfaceMethod(const intf; methodOffset: dword) : pointer;
begin
  result := pointer(pointer(dword(pointer(intf)^) + methodOffset)^);
end;

// ***************************************************************************

const
  IID_IDirectDraw2: TGUID = '{B3A6F3E0-2B43-11CF-A2DE-00AA00B93356}';

type
  IDirectDraw = ^TDirectDraw;
  PDirectDrawVMT = ^TDirectDrawVMT;
  TDirectDraw = record VMT: PDirectDrawVMT; end;
  TDirectDrawVMT = record
    QueryInterface: function (self: IDirectDraw; const IID: TGUID; out Obj): HResult; stdcall;
  end;
  IDirectDraw2 = Pointer;

const
  DD_OK    = HResult(0);
  DD_FALSE = HResult(S_FALSE);

var
  DirectDrawCreateNext : function (lpGUID: PGUID; out lplpDD: IDirectDraw; pUnkOuter: Pointer): HResult; stdcall = nil;
  SetDisplayModeNext: function (self: IDirectDraw; dwWidth, dwHeight, dwBpp, dwRefreshRate, dwFlags: DWORD): HResult; stdcall = nil;

function SetDisplayModeCallback(self: IDirectDraw; dwWidth, dwHeight, dwBpp, dwRefreshRate, dwFlags: DWORD): HResult; stdcall;
begin
  Result := SetDisplayModeNext(self, 800, 600, dwBpp, dwRefreshRate, dwFlags);
end;

function DirectDrawCreateCallback(lpGUID: PGUID; out lplpDD: IDirectDraw; pUnkOuter: Pointer): HResult; stdcall;
var
  DD2: IDirectDraw2;
begin
  try
    if @DirectDrawCreateNext=nil then
      Result := DD_FALSE
    else
      Result := DirectDrawCreateNext(lpGUID, lplpDD, pUnkOuter);
    if Result=DD_OK then
    begin
      if @SetDisplayModeNext=nil then
        if lplpDD<>nil then
        begin
          lplpDD.VMT.QueryInterface(lplpDD, IID_IDirectDraw2, DD2);
          HookCode(GetInterfaceMethod(DD2, $54), @SetDisplayModeCallback, @SetDisplayModeNext);
        end;
    end;
  except
    Result := DD_FALSE;
  end;
end;

begin
  HookAPI('ddraw.dll', 'DirectDrawCreate', @DirectDrawCreateCallback, @DirectDrawCreateNext);
end.

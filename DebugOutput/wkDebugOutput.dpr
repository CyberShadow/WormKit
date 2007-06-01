library wkDebugOutput;

{$IMAGEBASE $62E00000}

uses Windows, USysUtils, madCodeHook;

var 
  OutputDebugStringANext : procedure(Data: PAnsiChar); stdcall;
  OutputDebugStringWNext : procedure(Data: PWideChar); stdcall;

// ***************************************************************

procedure Log(S: ansistring);
var
  F: text;
begin
  Assign(F, ExtractFilePath(ParamStr(0))+'DebugOutput.log');
  {$I-}
  Append(F);
  {$I+}
  {$I-}
  if IOResult<>0 then 
    ReWrite(F);
  Write(F, '['+TimeStr+'] '+S);
  Close(f);
  {$I+}
  IOResult;
end;

// ***************************************************************

procedure OutputDebugStringACallback(Data: PAnsiChar); stdcall;
begin
  Log(Data);
  OutputDebugStringANext(Data);
end;

procedure OutputDebugStringWCallback(Data: PWideChar); stdcall;
begin
  Log(Data);
  OutputDebugStringWNext(Data);
end;

// ***************************************************************

begin
  Log(#13#10#13#10#13#10#13#10#13#10'------------------------------------------------------------------------------------------------------------------------------------------------------'#13#10#13#10#13#10#13#10#13#10#13#10);
  HookAPI('kernel32.dll', 'OutputDebugStringA',       @OutputDebugStringACallback,       @OutputDebugStringANext);
  HookAPI('kernel32.dll', 'OutputDebugStringW',       @OutputDebugStringWCallback,       @OutputDebugStringWNext);
end.

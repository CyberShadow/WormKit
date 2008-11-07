unit Utils;

interface

uses
  SysUtils;

procedure Log(S: string);
procedure AppendTo(FN, S: string);

implementation

procedure Log(S: string);
var
  F: text;
begin
  // logging to disk will work only if the file WormNAT.log exists
  if Copy(S, 1, 1)<>'-' then
    S:='['+TimeToStr(Now)+'] '+S;

  {$I-}
  Assign(F, ExtractFilePath(ParamStr(0))+'WormNAT2.log');
  Append(F);
  WriteLn(F, S);
  Close(f);
  {$I+}
  if IOResult<>0 then ;
end;

procedure AppendTo(FN, S: string);
var
  F: text;
begin
  {$I-}
  Assign(F, ExtractFilePath(ParamStr(0))+FN);
  Append(F);
  Write(F, S);
  Close(f);
  {$I+}
  if IOResult<>0 then ;
end;

end.

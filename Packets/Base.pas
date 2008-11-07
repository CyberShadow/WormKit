unit Base;

interface

function WinSockErrorCodeStr(Code: Integer): string;
function GetLine(var Source, Dest: string): Boolean;

implementation

{$INCLUDE WinSockCodes.inc}

function WinSockErrorCodeStr(Code: Integer): string;
var
  I: Integer;
begin
  Str(Code, Result);
  Result:='Error #'+Result;
  for I:=1 to High(WinSockErrors) do
    if (WinSockErrors[I].Code=Code)or(WinSockErrors[I].Code=Code+10000) then
      Result:=WinSockErrors[I].Text;
end;

function GetLine(var Source, Dest: string): Boolean;
var
  P, P1, P2: Integer;
begin
  P1:=Pos(#13, Source);
  P2:=Pos(#10, Source);
  if (P1=0) and (P2=0) then
  begin
    Dest:='';
    Result:=False;
    Exit
  end
  else
    if P1=0 then
      P:=P2
    else
    if P2=0 then
      P:=P1
    else
    if(P1<P2) then
      P:=P1
    else
      P:=P2;
  Result:=True;
  Dest:=Copy(Source, 1, P-1);
  Delete(Source, 1, P);
  if Copy(Source, 1, 1)=#10 then
    Delete(Source, 1, 1);
end;

end.

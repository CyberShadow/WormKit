const
 AlphabetLow    = 'éìàøýúùíóáœšïŸžæèñò';
 AlphabetHi     = 'ÉÌÀØÝÚÙÍÓÁŒŠÏŽÆÈÑÒ';

function UpCase(ACh:Char):Char; overload;
var
 LP:Integer;
begin
 Result:=ACh;
 if (ACh>='a') and (ACh<='z') then Dec(Result,32)
 else begin
  LP:=Pos(ACh,AlphabetLow);
  if LP=0 then Result:=ACh
  else Result:=AlphabetHi[LP];
 end;
end;

function UpCase(AStr:string):string; overload;
const
 AlphabetCZ     = 'éìàøýúùíóáœšïŸžæèñò';
 AlphabetCZEN   = 'eerrtyuuioassdzzccnn';

var
 LI:Integer;
begin
 Result:=AStr;
 for LI:=1 to Length(Result) do
  Result[LI]:=UpCase(Result[LI]);
end;

function LowCase(ACh:Char):Char; overload;
var
 LP:Integer;
begin
 Result:=ACh;
 if (ACh>='A') and (ACh<='Z') then Inc(Result,32)
 else begin
  LP:=Pos(ACh,AlphabetHi);
  if LP=0 then Result:=ACh
  else Result:=AlphabetLow[LP];
 end;
end;

function LowCase(AStr:string):string; overload;
var
 LI:Integer;
begin
 Result:=AStr;
 for LI:=1 to Length(Result) do
  Result[LI]:=LowCase(Result[LI]);
end;

function ChangeCase(ACh:Char):Char; overload;
var
 LP:Integer;
begin
 Result:=ACh;
 if (ACh>='A') and (ACh<='Z') then Inc(Result,32)
 else if (ACh>='a') and (ACh<='z') then Dec(Result,32)
 else begin
  LP:=Pos(ACh,AlphabetHi);
  if LP=0 then begin
   LP:=Pos(ACh,AlphabetLow);
   if LP=0 then Result:=ACh
   else Result:=AlphabetHi[LP];
  end else Result:=AlphabetLow[LP];
 end;
end;

function ChangeCase(AStr:string):string; overload;
var
 LI:Integer;
begin
 Result:=AStr;
 for LI:=1 to Length(Result) do
  Result[LI]:=ChangeCase(Result[LI]);
end;



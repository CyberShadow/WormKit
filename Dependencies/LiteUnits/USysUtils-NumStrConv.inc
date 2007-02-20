function IntToStr(AInt64:Int64):string; overload;
begin
 Str(AInt64,Result);
end;

function IntToStr(AInt:Integer):string; overload;
begin
 Str(AInt,Result);
end;

function IntToStr(ACard:Cardinal):string; overload;
begin
 Str(ACard,Result);
end;

function IntToStr(AWord:Word):string; overload;
begin
 Str(AWord,Result);
end;

function IntToStrLen(AInt:Integer;ADigits:Byte):string;
var
 LS:string;
 LI,LLen:Integer;
begin
 Result:=StringOfChar('0',ADigits);
 Str(AInt,LS);
 if Length(LS)>ADigits then LLen:=ADigits
 else LLen:=Length(LS);

 for LI:=0 to LLen-1 do
  Result[ADigits-LI]:=LS[Length(LS)-LI];
end;

function IntToHex(ACard:Cardinal;ADigits:Byte):string;
const
 HexArray:array[0..15] of Char=('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');
var
 LHex:string;
 LInt,LHInt:Cardinal;
begin
 LHex:=StringOfChar('0',ADigits);
 LInt:=ADigits;
 LHInt:=16;
 while ACard>0 do
 begin
  LHex[LInt]:=HexArray[(ACard mod LHint) mod 16];
  ACard:=ACard div 16;
  LHInt:=LHInt*16;
  if LHInt=0 then LHInt:=$FFFFFFFF;
  Dec(LInt);
 end;
 Result:=LHex;
end;

function StrToCardDef(AStr:string;ADef:Cardinal=0):Cardinal;
var
 LCode:Integer;
begin
 Val(AStr,Result,LCode);
 if LCode<>0 then Result:=ADef;
end;

function StrToCard(AStr:string):Cardinal;
begin
 Result:=StrToCardDef(AStr);
end;

function StrToIntDef(AStr:string;ADef:Int64=0):Int64;
var
 LCode:Integer;
begin
 Val(AStr,Result,LCode);
 if LCode<>0 then Result:=ADef;
end;

function StrToInt(AStr:string):Integer;
begin
 Result:=StrToIntDef(AStr);
end;

{$APPTYPE CONSOLE}

uses
  PngImageLite, SysUtils;

var
  F: Text;
  Data: string;
  I, J, L, Row: Integer;
  P: TPngObject;
begin
  Assign(F, ParamStr(3));
  Reset(F);
  ReadLn(F, Data);
  Write('Data: ', Data, ' ');
  while not EoF(F) do
    begin
    ReadLn(F, L, I);
    Write(IntToHex(I,L*2), ' ');
    SetLength(Data, Length(Data)+L);
    Move(I, Data[Length(Data)-L+1], L);
    end;
  Close(F);
  WriteLn;Write('Hex: ');
  for I:=1 to Length(Data) do
    Write(IntToHex(Ord(Data[I]), 2), ' ');
  WriteLn;WriteLn('Raw: ', Data);

  Row:=StrToIntDef(ParamStr(4), 695);

  P:=TPngObject.Create;
  P.LoadFromFile(ParamStr(1));

  // the least significant bit is first               //          xxxx.... ....xxxx
  for I:=1 to Length(Data) do
    for J:=0 to 7 do
      if Ord(Data[I]) and (1 shl J) <> 0 then
        P.Pixels[I*8 + J, Row] := $FFFFFF
      else
        P.Pixels[I*8 + J, Row] := $000000;

  P.SaveToFile(ParamStr(2));
  P.Free;
end.
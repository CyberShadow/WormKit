unit UList;

interface

uses Windows;
const
 MaxListSize=Maxint div 16;

type
  PPointerList=^TPointerList;
  TPointerList=array[0..MaxListSize-1] of Pointer;
  TListSortCompare=function (AItem1,AItem2:Pointer):Integer;
  TListAssignOp=(laCopy,laAnd,laOr,laXor,laSrcUnique,laDestUnique);

  TList=class(TObject)
  private
   FList:PPointerList;
   FCount:Integer;
   FCapacity:Integer;
  protected
   function Get(AIndex:Integer):Pointer;
   procedure Grow; virtual;
   procedure Put(AIndex:Integer;AItem:Pointer);
   procedure SetCapacity(ANewCapacity:Integer);
   procedure SetCount(ANewCount:Integer);
  public
   destructor Destroy; override;
   function Add(AItem:Pointer):Integer;
   procedure Clear; virtual;
   procedure Delete(AIndex:Integer);
   procedure Exchange(AIndex1,AIndex2:Integer);
   function Expand:TList;
   function Extract(AItem:Pointer):Pointer;
   function First:Pointer;
   function IndexOf(AItem:Pointer):Integer;
   procedure Insert(AIndex:Integer;AItem:Pointer);
   function Last:Pointer;
   procedure Move(ACurIndex,ANewIndex:Integer);
   function Remove(AItem:Pointer):Integer;
   procedure Pack;
   procedure Sort(ACompare:TListSortCompare);
   procedure Assign(AListA:TList;AOperator:TListAssignOp=laCopy;AListB:TList=nil);
   property Capacity:Integer read FCapacity write SetCapacity;
   property Count:Integer read FCount write SetCount;
   property Items[Index:Integer]:Pointer read Get write Put; default;
   property List:PPointerList read FList;
  end;

implementation

{ TList }

destructor TList.Destroy;
begin
 Clear;
end;

function TList.Add(AItem:Pointer):Integer;
begin
 Result:=FCount;
 if Result=FCapacity then Grow;
 FList^[Result]:=AItem;
 Inc(FCount);
end;

procedure TList.Clear;
begin
 SetCount(0);
 SetCapacity(0);
end;

procedure TList.Delete(AIndex:Integer);
begin
 if (AIndex<0) or (AIndex>=FCount) then Exit;
 Dec(FCount);
 if AIndex<FCount then System.Move(FList^[AIndex+1],FList^[AIndex],(FCount-AIndex)*SizeOf(Pointer));
end;

procedure TList.Exchange(AIndex1,AIndex2:Integer);
var
 LItem:Pointer;
begin
 if (AIndex1<0) or (AIndex1>=FCount) then Exit;
 if (AIndex2<0) or (AIndex2>=FCount) then Exit;
 LItem:=FList^[AIndex1];
 FList^[AIndex1]:=FList^[AIndex2];
 FList^[AIndex2]:=LItem;
end;

function TList.Expand:TList;
begin
 if FCount=FCapacity then Grow;
 Result:=Self;
end;

function TList.First:Pointer;
begin
 Result:=Get(0);
end;

function TList.Get(AIndex:Integer):Pointer;
begin
 Result:=nil;
 if (AIndex<0) or (AIndex>=FCount) then Exit;
 Result:=FList^[AIndex];
end;

procedure TList.Grow;
var
 LDelta:Integer;
begin
 if FCapacity>64 then LDelta:=FCapacity div 4
 else if FCapacity>8 then LDelta:=16
 else LDelta:=4;
 SetCapacity(FCapacity+LDelta);
end;

function TList.IndexOf(AItem:Pointer):Integer;
begin
 Result:=0;
 while (Result<FCount) and (FList^[Result]<>AItem) do Inc(Result);
 if Result=FCount then Result:=-1;
end;

procedure TList.Insert(AIndex:Integer;AItem:Pointer);
begin
 if (AIndex<0) or (AIndex>FCount) then Exit;
 if FCount=FCapacity then Grow;
 if AIndex<FCount then System.Move(FList^[AIndex],FList^[AIndex+1],(FCount-AIndex)*SizeOf(Pointer));
 FList^[AIndex]:=AItem;
 Inc(FCount);
end;

function TList.Last:Pointer;
begin
 Result:=Get(FCount-1);
end;

procedure TList.Move(ACurIndex,ANewIndex:Integer);
var
 LItem:Pointer;
begin
 if ACurIndex<>ANewIndex then
 begin
  if (ANewIndex<0) or (ANewIndex>=FCount) then Exit;
  LItem:=Get(ACurIndex);
  FList^[ACurIndex]:=nil;
  Delete(ACurIndex);
  Insert(ANewIndex,nil);
  FList^[ANewIndex]:=LItem;
 end;
end;

procedure TList.Put(AIndex:Integer;AItem:Pointer);
begin
 if (AIndex<0) or (AIndex>=FCount) then Exit;
 if AItem<>FList^[AIndex] then FList^[AIndex]:=AItem;
end;

function TList.Remove(AItem:Pointer):Integer;
begin
 Result:=IndexOf(AItem);
 if Result>=0 then Delete(Result);
end;

procedure TList.Pack;
var
 LI:Integer;
begin
 for LI:=FCount-1 downto 0 do
  if Items[LI]=nil then Delete(LI);
end;

procedure TList.SetCapacity(ANewCapacity:Integer);
begin
 if (ANewCapacity<FCount) or (ANewCapacity>MaxListSize) then Exit;
 if ANewCapacity<>FCapacity then
 begin
  ReallocMem(FList,ANewCapacity*SizeOf(Pointer));
  FCapacity:=ANewCapacity;
 end;
end;

procedure TList.SetCount(ANewCount:Integer);
var
 LI:Integer;
begin
 if (ANewCount<0) or (ANewCount>MaxListSize) then Exit;
 if ANewCount>FCapacity then SetCapacity(ANewCount);
 if ANewCount>FCount then FillChar(FList^[FCount],(ANewCount-FCount)*SizeOf(Pointer),0)
 else for LI:=FCount-1 downto ANewCount do Delete(LI);
 FCount:=ANewCount;
end;

procedure QuickSort(ASortList:PPointerList;AL,AR:Integer;ASCompare:TListSortCompare);
var
 LI,LJ:Integer;
 LP,LT:Pointer;
begin
 repeat
  LI:=AL;
  LJ:=AR;
  LP:=ASortList^[(AL+AR) shr 1];
  repeat
   while ASCompare(ASortList^[LI],LP)<0 do Inc(LI);
   while ASCompare(ASortList^[LJ],LP)>0 do Dec(LJ);
   if LI<=LJ then
   begin
    LT:=ASortList^[LI];
    ASortList^[LI]:=ASortList^[LJ];
    ASortList^[LJ]:=LT;
    Inc(LI);
    Dec(LJ);
   end;
  until LI>LJ;
  if AL<LJ then QuickSort(ASortList,AL,LJ,ASCompare);
  AL:=LI;
 until LI>=AR;
end;

procedure TList.Sort(ACompare:TListSortCompare);
begin
 if (FList<>nil) and (Count>0) then QuickSort(FList,0,Count-1,ACompare);
end;

function TList.Extract(AItem:Pointer):Pointer;
var
 LI:Integer;
begin
 Result:=nil;
 LI:=IndexOf(AItem);
 if LI>=0 then
 begin
  Result:=AItem;
  FList^[LI]:=nil;
  Delete(LI);
 end;
end;

procedure TList.Assign(AListA:TList;AOperator:TListAssignOp;AListB:TList);
var
 LI:Integer;
 LTemp,LSource:TList;
begin
 // ListB given?
 if AListB<>nil then
 begin
  LSource:=AListB;
  Assign(AListA);
 end else LSource:=AListA;

 // on with the show
 case AOperator of
  laCopy:begin                          // 12345, 346 = 346 : only those in the new list
   Clear;
   Capacity:=LSource.Capacity;
   for LI:=0 to LSource.Count-1 do Add(LSource[LI]);
  end;
  laAnd:for LI:=Count-1 downto 0 do     // 12345, 346 = 34 : intersection of the two lists
         if LSource.IndexOf(Items[LI])=-1 then Delete(LI);
  laOr:for LI:=0 to LSource.Count-1 do  // 12345, 346 = 123456 : union of the two lists
        if IndexOf(LSource[LI])=-1 then Add(LSource[LI]);
  laXor:begin                           // 12345, 346 = 1256 : only those not in both lists
   LTemp:=TList.Create; // Temp holder of 4 byte values
   try
    LTemp.Capacity:=LSource.Count;
    for LI:=0 to LSource.Count-1 do
     if IndexOf(LSource[LI])=-1 then LTemp.Add(LSource[LI]);
    for LI:=Count-1 downto 0 do
     if LSource.IndexOf(Items[LI])<>-1 then Delete(LI);
    LI:=Count+LTemp.Count;
    if Capacity<LI then Capacity:=LI;
    for LI:=0 to LTemp.Count-1 do Add(LTemp[LI]);
   finally
    LTemp.Free;
   end;
  end;
  laSrcUnique:for LI:=Count-1 downto 0 do       // 12345, 346 = 125 : only those unique to source
               if LSource.IndexOf(Items[LI])<>-1 then Delete(LI);
  laDestUnique:begin                    // 12345, 346 = 6 : only those unique to dest
   LTemp:=TList.Create;
   try
    LTemp.Capacity:=LSource.Count;
    for LI:=LSource.Count-1 downto 0 do
     if IndexOf(LSource[LI])=-1 then LTemp.Add(LSource[LI]);
    Assign(LTemp);
   finally
    LTemp.Free;
   end;
  end;
 end;
end;

end.

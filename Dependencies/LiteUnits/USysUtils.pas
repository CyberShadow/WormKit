{$I-}
{checked}
unit USysUtils;

interface
uses Windows;
const
 WM_QUIT=$0012;
 WM_USER=$0400;

 HoursPerDay   = 24;
 MinsPerDay    = HoursPerDay * 60;
 SecsPerDay    = MinsPerDay * 60;
 MSecsPerDay   = SecsPerDay * 1000;

type
{ Standard Character set type }
  TSysCharSet = set of Char;

{ Set access to an integer }
  TIntegerSet = set of 0..SizeOf(Integer) * 8 - 1;

{ Type conversion records }
  WordRec = packed record
    case Integer of
      0: (Lo, Hi: Byte);
      1: (Bytes: array [0..1] of Byte);
  end;

  LongRec = packed record
    case Integer of
      0: (Lo, Hi: Word);
      1: (Words: array [0..1] of Word);
      2: (Bytes: array [0..3] of Byte);
  end;

  Int64Rec = packed record
    case Integer of
      0: (Lo, Hi: Cardinal);
      1: (Cardinals: array [0..1] of Cardinal);
      2: (Words: array [0..3] of Word);
      3: (Bytes: array [0..7] of Byte);
  end;

{ General arrays }
  PByteArray = ^TByteArray;
  TByteArray = array[0..32767] of Byte;

  PWordArray = ^TWordArray;
  TWordArray = array[0..16383] of Word;

{ Generic procedure pointer }
  TProcedure = procedure;

{ Generic filename type }
  TFileName = type string;

function SystemShell(ACommand:PChar):Cardinal; stdcall; external 'msvcrt.dll' name 'system';

function IntToStr(AInt64:Int64):string; overload;
function IntToStr(AInt:Integer):string; overload;
function IntToStr(ACard:Cardinal):string; overload;
function IntToStr(AWord:Word):string; overload;
function IntToStrLen(AInt:Integer;ADigits:Byte):string;
function StrToCardDef(AStr:string;ADef:Cardinal=0):Cardinal;
function StrToCard(AStr:string):Cardinal;
function StrToIntDef(AStr:string;ADef:Int64=0):Int64;
function StrToInt(AStr:string):Integer;
function IntToHex(ACard:Cardinal;ADigits:Byte):string;
function HexToInt(AHex:string):Cardinal;
function UpCase(ACh:Char):Char; overload;
function UpCase(AStr:string):string; overload;
function UpperCase(AStr:string):string; 
function LowCase(ACh:Char):Char; overload;
function LowCase(AStr:string):string; overload;
function LowerCase(AStr:string):string; 
function ChangeCase(ACh:Char):Char; overload;
function ChangeCase(AStr:string):string; overload;
procedure WaitPoint(ATimeOut:Cardinal=10);
procedure Wait(ASec:Cardinal);
function SystemTimeToStr(ASystemTime:TSystemTime):string;
function FileTimeToStr(AFileTime:TFileTime):string;
function Time:TSystemTime;
function TimeStr:string;
function IsLeapYear(AYear:Word):Boolean;
function Now:TDateTime;
function RealFileSize(AFileName:string):Cardinal;
function DeleteFile(AFile:string):Boolean;
function CopyFile(ASourceFile,ADestFile:string;ACantRewrite:Boolean):Boolean;
function MoveFile(AFileFrom,AFileTo:string):Boolean;
function FileExists(AFileName:string):Boolean;
function DirectoryExists(ADirectory:string):Boolean;
function ForceDirectories(APath:string):Boolean;
function ExtractFilePath(APath:string):string;
function ExtractFileName(APath:string):string;
function ExtractFileExt(const FileName: string): string;
function ExpandFileName(const FileName: string): string;
function FirstChar(AStr:string;AChar:Char):Boolean;
function LastChar(AStr:string;AChar:Char):Boolean;
procedure AddLastBackSlash(var AStr:string);
function IncludeTrailingBackSlash(AStr:string) : string;
procedure DeleteLastBackSlash(var AStr:string);
function Trim(AStr:string):string;
function StrReplace(AStr:string;ASubStr,ANewStr:string;ACaseSens:Boolean=False):string;

function SysErrorMessage(ErrorCode: Integer): string;

implementation
type
 TLongRec=packed record
 case Integer of
  0:(Lo,Hi:Word);
  1:(Words:array [0..1]of Word);
  2:(Bytes:array [0..3]of Byte);
 end;

const
 DateDelta     = 693594;

type
 PDayTable=^TDayTable;
 TDayTable=array[1..12] of Word;

const
 MonthDays:array[Boolean] of TDayTable=
    ((31,28,31,30,31,30,31,31,30,31,30,31),
     (31,29,31,30,31,30,31,31,30,31,30,31));


{$INCLUDE USysUtils-NumStrConv.inc}

{$R-}
function HexToInt(AHex:string):Cardinal;
var
 LI,LO:Byte;
 LM:Cardinal;
begin
 LM:=1;
 Result:=0;
 AHex:=UpCase(AHex);
 for LI:=Length(AHex) downto 1 do
 begin
  if not ((AHex[LI] in ['0'..'9']) or (AHex[LI] in ['A'..'F'])) then
  begin
   Result:=0;
   Exit;
  end;
  if AHex[LI] in ['0'..'9'] then LO:=48 else LO:=55;
  LO:=Ord(AHex[LI])-LO;
  Result:=Result+LO*LM;
  LM:=LM shl 4;
 end;
end;
{$R+}

{$INCLUDE USysUtils-Case.inc}

function UpperCase(AStr:string):string; 
begin
  Result:=UpCase(AStr);
end;

function LowerCase(AStr:string):string; 
begin
  Result:=LowCase(AStr);
end;

function FileAge(const FileName:string):Integer;
begin
 Result:=-1;
end;

procedure WaitPoint(ATimeout:Cardinal=10);
 procedure ProcessMessages;
 var
  LMsg:TMsg;
 begin
  while PeekMessage(LMsg,0,0,0,PM_REMOVE) do
   if LMsg.Message=WM_QUIT then Halt(0);
 end;
begin
 ProcessMessages;
 Sleep(ATimeout);
end;

procedure Wait(ASec:Cardinal);
var
 LT1,LT2,LT3:Cardinal;
begin
 LT1:=GetTickCount;
 repeat
  WaitPoint;
  LT2:=GetTickCount;
  if LT1>LT2 then LT1:=0;
  LT3:=LT2-LT1;
 until LT3>=ASec*1000;
end;

function SystemTimeToStr(ASystemTime:TSystemTime):string;
begin
 with ASystemTime do
  Result:=IntToStrLen(wDay,2)+'.'+IntToStrLen(wMonth,2)+'.'+IntToStrLen(wYear,2)+' '+IntToStrLen(wHour,2)+':'+IntToStrLen(wMinute,2)+':'+IntToStrLen(wSecond,2);
end;

function FileTimeToStr(AFileTime:TFileTime):string;
var
 LSystemTime:TSystemTime;
begin
 FileTimeToSystemTime(AFileTime,LSystemTime);
 Result:=SystemTimeToStr(LSystemTime);
end;

function Time:TSystemTime;
begin
 GetLocalTime(Result);
end;

function TimeStr:string;
begin
 Result:=SystemTimeToStr(Time);
end;

function IsLeapYear(AYear:Word):Boolean;
begin
 Result:=(AYear mod 4=0) and ((AYear mod 100<>0) or (AYear mod 400=0));
end;

function TryEncodeTime(AHour,AMin,ASec,AMSec:Word;out OTime:TDateTime):Boolean;
begin
 Result:=False;
 if (AHour<24) and (AMin<60) and (ASec<60) and (AMSec<1000) then
 begin
  OTime:=(AHour*3600000+AMin*60000+ASec*1000+AMSec)/MSecsPerDay;
  Result:=True;
 end;
end;

function EncodeTime(AHour,AMin,ASec,AMSec:Word):TDateTime;
begin
 if not TryEncodeTime(AHour,AMin,ASec,AMSec,Result) then Result:=0;
end;

function TryEncodeDate(AYear,AMonth,ADay:Word;out ODate:TDateTime):Boolean;
var
 LI:Integer;
 LDayTable:PDayTable;
begin
 Result:=False;
 LDayTable:=@MonthDays[IsLeapYear(AYear)];
 if (AYear>=1) and (AYear<=9999) and (AMonth>=1) and (AMonth<=12) and
   (ADay>=1) and (ADay<=LDayTable^[AMonth]) then
 begin
  for LI:=1 to AMonth-1 do Inc(ADay,LDayTable^[LI]);
  LI:=AYear-1;
  ODate:=LI*365+LI div 4-LI div 100+LI div 400+ADay-DateDelta;
  Result := True;
 end;
end;

function EncodeDate(Year, Month, Day: Word): TDateTime;
begin
  if not TryEncodeDate(Year, Month, Day, Result) then Result:=0;
end;

function Now:TDateTime;
var
 SystemTime:TSystemTime;
begin
 GetLocalTime(SystemTime);
 with SystemTime do
  Result:=EncodeDate(wYear,wMonth,wDay)+
   EncodeTime(wHour,wMinute,wSecond,wMilliseconds);
end;

function RealFileSize(AFileName:string):Cardinal;
var
 LHandle:THandle;
begin
 Result:=$FFFFFFFF;;
 LHandle:=CreateFile(PChar(AFileName),GENERIC_READ,0,nil,OPEN_EXISTING,0,0);
 if LHandle=INVALID_HANDLE_VALUE then Exit;
 Result:=GetFileSize(LHandle,nil);
 CloseHandle(LHandle);
end;

function DeleteFile(AFile:string):Boolean;
begin
 SetFileAttributes(PChar(AFile),0);
 Result:=Windows.DeleteFile(PChar(AFile));
end;

function CopyFile(ASourceFile,ADestFile:string;ACantRewrite:Boolean):Boolean;
begin
 Result:=Windows.CopyFile(PChar(ASourceFile),PChar(ADestFile),ACantRewrite);
end;

function MoveFile(AFileFrom,AFileTo:string):Boolean;
begin
 Result:=Windows.MoveFile(PChar(AFileFrom),PChar(AFileTo));
end;

function FileExists(AFileName:string):Boolean;
var
 LHandle:THandle;
 LFindData:TWin32FindData;
begin
 Result:=False;
 LHandle:=FindFirstFile(PChar(AFileName),LFindData);
 if LHandle<>INVALID_HANDLE_VALUE then
 begin
  Windows.FindClose(LHandle);
  Result:=LFindData.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY=0;
 end;
end;

function DirectoryExists(ADirectory:string):Boolean;
var
 LCode:Cardinal;

begin
 LCode:=GetFileAttributes(PChar(ADirectory));
 Result:=(LCode<>$FFFFFFFF) and (FILE_ATTRIBUTE_DIRECTORY and LCode<>0);
end;

function ForceDirectories(APath:string):Boolean;
begin
 Result:=True;
  if APath = '' then
  begin
    Result := False;
    Exit
  end;
 DeleteLastBackSlash(APath);
  if (Length(APath) < 3) or DirectoryExists(APath)
    or (ExtractFilePath(APath) = APath) then Exit; // avoid 'xyz:\' problem.
  Result := ForceDirectories(ExtractFilePath(APath)) and CreateDirectory(PChar(APath), nil);
end;

function ExtractFilePath(APath:string):string;
var
 LI,LJ:Integer;
begin
 if (Length(APath)<>0) and (Pos('\',APath)>0) then
 begin
  LJ:=0;
  for LI:=Length(APath) downto 1 do
   if APath[LI]='\' then
   begin
    LJ:=LI;
    Break;
   end;
  Result:=Copy(APath,1,LJ);
 end else Result:='';
end;

function ExtractFileName(APath:string):string;
var
 LI,LJ:Integer;
begin
 if Length(APath)<>0 then
 begin
  LJ:=0;
  for LI:=Length(APath) downto 1 do
   if APath[LI]='\' then
   begin
    LJ:=LI;
    Break;
   end;
  Result:=Copy(APath,LJ+1,MaxInt);
 end else Result:='';
end;

function ExtractFileExt(const FileName: string): string;
var
  S: string;
  I: Integer;
begin
  S := ExtractFileName(FileName);
  if Length(S)<>0 then
    begin
    for I:=Length(S) downto 1 do
      if S[I]='.' then
        begin
        Result:=Copy(S, I, MaxInt);
        Exit;
        end;
    end;
  Result:='';
end;

function ExpandFileName(const FileName: string): string;
var
  FName: PChar;
  Buffer: array[0..MAX_PATH - 1] of Char;
begin
  SetString(Result, Buffer, GetFullPathName(PChar(FileName), SizeOf(Buffer),
    Buffer, FName));
end;

function FirstChar(AStr:string;AChar:Char):Boolean;
begin
 Result:=False;
 if Length(AStr)=0 then Exit;
 Result:=AStr[1]=AChar;
end;

function LastChar(AStr:string;AChar:Char):Boolean;
begin
 Result:=False;
 if Length(AStr)=0 then Exit;
 Result:=AStr[Length(AStr)]=AChar;
end;

procedure AddLastBackSlash(var AStr:string);
begin
 if not ((Length(AStr)=0) or LastChar(AStr,'\')) then AStr:=AStr+'\';
end;

function IncludeTrailingBackSlash(AStr:string) : string;
begin
 if not ((Length(AStr)=0) or LastChar(AStr,'\')) then Result:=AStr+'\' else Result:=AStr;
end;

procedure DeleteLastBackSlash(var AStr:string);
begin
 if (Length(AStr)<>0) and LastChar(AStr,'\') then Delete(AStr,Length(AStr),1);
end;

function Trim(AStr:string):string;
var
 LI,LLen:Integer;
begin
 LLen:=Length(AStr);
 LI:=1;
 while (LI<=LLen) and (AStr[LI]<=' ') do Inc(LI);
 if LI>LLen then Result:='' else
 begin
  while AStr[LLen]<=' ' do Dec(LLen);
  Result:=Copy(AStr,LI,LLen-LI+1);
 end;
end;

function StrReplace(AStr:string;ASubStr,ANewStr:string;ACaseSens:Boolean=False):string;
var
 LStr:string;
 LP:Integer;
begin
 if not ACaseSens then
 begin
  ASubStr:=UpCase(ASubStr);
  LStr:=UpCase(AStr);
 end else LStr:=AStr;
 LP:=1;
 while LP>0 do
 begin
  LP:=Pos(ASubStr,LStr);
  if LP>0 then
  begin
   LStr:=Copy(LStr,1,LP-1)+ANewStr+Copy(LStr,LP+Length(ASubStr),MaxInt);
   AStr:=Copy(AStr,1,LP-1)+ANewStr+Copy(AStr,LP+Length(ASubStr),MaxInt);
  end;
 end;
 Result:=AStr;
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

end.

unit UProcAPI;

interface
uses Windows;

function EnableDebugPrivilege:Boolean;
function ModuleName2PID(AName:string):Cardinal;
function EnumProcesses(AProcessesId:Pointer;ASizeOfPID:Cardinal;ADone:Pointer):Cardinal; stdcall;
function EnumProcessModules(AProcess:THandle;AModules:Pointer;ASizeOfModule:Cardinal;ADone:Pointer):Cardinal; stdcall;
function GetModuleBaseNameA(AProcess:THandle;AModule:HMODULE;AProcessName:PChar;ASizeOfName:Cardinal):Cardinal; stdcall; 

implementation

{$INCLUDE USysUtils-Case.inc}

type
 TSystemInformationClass=(
  SystemBasicInformation,SystemProcessorInformation,SystemPerformanceInformation,SystemTimeOfDayInformation,
  SystemNotImplemented1,SystemProcessesAndThreadsInformation,SystemCallCounts,SystemConfigurationInformation,
  SystemProcessorTimes,SystemGlobalFlag,SystemNotImplemented2,SystemModuleInformation,SystemLockInformation,
  SystemNotImplemented3,SystemNotImplemented4,SystemNotImplemented5,SystemHandleInformation,SystemObjectInformation,
  SystemPagefileInformation,SystemInstructionEmulationCounts,SystemInvalidInfoClass1,SystemCacheInformation,
  SystemPoolTagInformation,SystemProcessorStatistics,SystemDpcInformation,SystemNotImplemented6,
  SystemLoadImage,SystemUnloadImage,SystemTimeAdjustment,SystemNotImplemented7,SystemNotImplemented8,
  SystemNotImplemented9,SystemCrashDumpInformation,SystemExceptionInformation,SystemCrashDumpStateInformation,
  SystemKernelDebuggerInformation,SystemContextSwitchInformation,SystemRegistryQuotaInformation,
  SystemLoadAndCallImage,SystemPrioritySeparation,SystemNotImplemented10,SystemNotImplemented11,
  SystemInvalidInfoClass2,SystemInvalidInfoClass3,SystemTimeZoneInformation,SystemLookasideInformation,
  SystemSetTimeSlipEvent,SystemCreateSession,SystemDeleteSession,SystemInvalidInfoClass4,
  SystemRangeStartInformation,SystemVerifierInformation,SystemAddVerifier,SystemSessionProcessesInformation);
 TProcessInfoClass=(
  ProcessBasicInformation,ProcessQuotaLimits,ProcessIoCounters,ProcessVmCounters,ProcessTimes,
  ProcessBasePriority,ProcessRaisePriority,ProcessDebugPort,ProcessExceptionPort,ProcessAccessToken,
  ProcessLdtInformation,ProcessLdtSize,ProcessDefaultHardErrorMode,ProcessIoPortHandlers,
  ProcessPooledUsageAndLimits,ProcessWorkingSetWatch,ProcessUserModeIOPL,ProcessEnableAlignmentFaultFixup,
  ProcessPriorityClass,ProcessWx86Information,ProcessHandleCount,ProcessAffinityMask,ProcessPriorityBoost,
  ProcessDeviceMap,ProcessSessionInformation,ProcessForegroundInformation,ProcessWow64Information,
  MaxProcessInfoClass);




function NtQuerySystemInformation(ASystemInformationClass:TSystemInformationClass;out OSystemInformation:Pointer;
                                  ASystemInformationLength:Cardinal;out OReturnLength:Pointer):Cardinal; stdcall; external 'ntdll.dll' name 'NtQuerySystemInformation';

function NtQueryInformationProcess(AProcessHandle:THandle;AProcessInformationClass:TProcessInfoClass;
                                   out OProcessInformation:Pointer;AProcessInformationLength:Cardinal;
                                   out OReturnLength:Pointer):Cardinal; stdcall; external 'ntdll.dll' name 'NtQueryInformationProcess';
function RtlNtStatusToDosError(AStatus:Cardinal):Cardinal; stdcall; external 'ntdll.dll' name 'RtlNtStatusToDosError';

function EnumProcesses(AProcessesId:Pointer;ASizeOfPID:Cardinal;ADone:Pointer):Cardinal; stdcall; assembler;
asm
 pop ebp                                //fucking delphi call

 mov eax,fs:000000000h
 push ebp
 mov ebp,esp
 push 0FFFFFFFFh
 push 0731B3448h
 push 0731B2E38h
 push eax
 mov fs:000000000h,esp
 sub esp,014h
 push ebx
 push esi
 push edi
 mov esi,08000h
 xor edi,edi
 mov dword ptr [ebp-018h],esp

@loc_731B2B37:
 push esi
 push edi
 call LocalAlloc
 mov dword ptr [ebp-01Ch],eax
 cmp eax,edi
 jz @loc_731B2C12
 push edi
 push esi
 push eax
 push 005h
 call NtQuerySystemInformation
 cmp eax,0C0000004h
 jnz @loc_731B2B6D
 push dword ptr [ebp-01Ch]
 call LocalFree
 add esi,08000h
 jmp @loc_731B2B37

@loc_731B2B6D:
 test eax,eax
 jge @loc_731B2B84
 push eax
 call RtlNtStatusToDosError
 push eax
 call SetLastError
 jmp @loc_731B2C12

@loc_731B2B84:
 xor esi,esi
 mov edx,dword ptr [ebp+00Ch]
 shr edx,002h
 xor edi,edi
 mov ecx,dword ptr [ebp+008h]

@loc_731B2B91:
 mov eax,dword ptr [ebp-01Ch]
 add eax,esi
 cmp edi,edx
 jnb @loc_731B2BAF
 mov dword ptr [ebp-004h],000000000h
 mov ebx,dword ptr [eax+044h]
 mov dword ptr [ecx+edi*004h],ebx
 inc edi
 mov dword ptr [ebp-004h], 0FFFFFFFFh

@loc_731B2BAF:
 mov eax,dword ptr [eax]
 add esi,eax
 test eax,eax
 jnz @loc_731B2B91
 mov esi,001h
 mov dword ptr [ebp-004h],esi
 lea ecx,ds:000000000h [edi*004h]
 mov eax,[ebp+10h]
 mov dword ptr [eax],ecx
 mov dword ptr [ebp-004h],0FFFFFFFFh
 push dword ptr [ebp-1Ch]
 call LocalFree
 mov eax,esi
 jmp @loc_731B2C14

@loc_731B2C12:

 xor eax,eax

@loc_731B2C14:
 mov ecx,dword ptr [ebp-010h]
 pop edi
 mov fs:000000000h,ecx
 pop esi
 pop ebx
 mov esp,ebp
 pop ebp

 ret 0000Ch
end;

function EnumProcessModules(AProcess:THandle;AModules:Pointer;ASizeOfModule:Cardinal;ADone:Pointer):Cardinal; stdcall; assembler;
asm
 pop ebp                                //fucking delphi call

 mov eax,fs:000000000h
 push ebp
 mov ebp,esp
 push 0FFFFFFFFh
 push 0731B3178h
 push 0731B2E38h
 push eax
 mov fs:000000000h,esp
 sub esp,078h
 lea eax,dword ptr [ebp-040h]
 push ebx
 push esi
 push edi
 mov dword ptr [ebp-018h],esp
 push 000h
 push 018h
 push eax
 push 000h
 push dword ptr [ebp+008h]
 call NtQueryInformationProcess
 test eax,eax
 jge @loc_731B15BF
 push eax
 call RtlNtStatusToDosError
 push eax
 call SetLastError
 jmp @loc_731B169E

@loc_731B15BF:
 push 000h
 lea eax,dword ptr [ebp-028h]
 push 004h
 push eax
 mov eax,dword ptr [ebp-03Ch]
 add eax,00Ch
 push eax
 push dword ptr [ebp+008h]
 call ReadProcessMemory 
 test eax,eax
 jz @loc_731B169E
 mov esi,dword ptr [ebp-028h]
 push 000h
 add esi,014h
 push 004
 lea eax,[ebp-01Ch]
 push eax
 push esi
 push dword ptr [ebp+008h]
 call ReadProcessMemory
 test eax,eax
 jz @loc_731B169E
 mov eax,dword ptr [ebp+010h]
 xor edi,edi
 shr eax,002h
 cmp esi,dword ptr [ebp-01Ch]
 mov dword ptr [ebp-024h],eax
 jz @loc_731B1657
 mov ebx,dword ptr [ebp+00Ch]

@loc_731B1612:
 mov eax,[ebp-01Ch]
 push 000h
 sub eax,008h
 push 48h
 lea ecx,[ebp-088h]
 push ecx
 push eax
 push dword ptr [ebp+008h]
 call ReadProcessMemory 
 test eax,eax
 jz @loc_731B169E
 cmp edi, [ebp-24h] 
 jnb @loc_731B1649
 mov dword ptr [ebp-004h],000000000h
 mov eax,dword ptr [ebp-070h]
 mov dword ptr [ebx],eax
 mov dword ptr [ebp-4], 0FFFFFFFFh

@loc_731B1649:    
 add ebx,004h  
 inc edi  
 mov eax,dword ptr [ebp-080h]
 mov dword ptr [ebp-01Ch],eax
 cmp esi,eax
 jnz @loc_731B1612 

@loc_731B1657:    
 mov eax,001h
 mov dword ptr [ebp-004h],eax
 lea edx,ds:000000000h [edi*004h]
 mov ecx,dword ptr [ebp+014h]
 mov dword ptr [ecx],edx
 mov dword ptr [ebp-004h],0FFFFFFFFh
 jmp @loc_731B16A0

@loc_731B169E:
 xor eax,eax

@loc_731B16A0:
 mov ecx,dword ptr [ebp-010h]
 pop edi
 mov fs:000000000h,ecx
 pop esi
 pop ebx
 mov esp,ebp
 pop ebp
 ret 00010h
end;

procedure sub_731B14A5; assembler; stdcall;
asm
 push ebp
 mov ebp,esp
 sub esp,020h
 push ebx
 lea eax,dword ptr [ebp-020h]
 push esi
 push edi
 push 000h
 mov esi,dword ptr [ebp+008h]
 push 018h
 push eax
 push 000h
 push esi
 call NtQueryInformationProcess
 test eax,eax
 jge @loc_731B14D3
 push eax
 call RtlNtStatusToDosError
 push eax
 jmp @loc_731B1557

@loc_731B14D3:
 cmp dword ptr [ebp+00Ch],000h
 mov edi,dword ptr [ebp-01Ch]
 jnz @loc_731B14F3
 push 000h
 lea eax,dword ptr [ebp+00Ch]
 push 004h
 lea ecx,dword ptr [edi+008h]
 push eax
 push ecx
 push esi
 call ReadProcessMemory
 test eax,eax
 jz @loc_731B155D

@loc_731B14F3:
 push 000h
 lea eax,dword ptr [ebp-008h]
 push 004h
 add edi,00Ch 
 push eax
 push edi
 push esi
 call ReadProcessMemory
 test eax,eax
 jz @loc_731B155D
 mov edi,dword ptr [ebp-008h]
 push 000h
 add edi,014h
 push 004h
 lea eax,dword ptr [ebp-004h] 
 push eax
 push edi
 push esi
 call ReadProcessMemory
 test eax,eax
 jz @loc_731B155D
 cmp dword ptr [ebp-004h],edi
 jz @loc_731B1555
 mov ebx,dword ptr [ebp+010h]

@loc_731B152C:
 mov eax,dword ptr [ebp-004h]
 push 000h
 sub eax,008h
 push 048h
 push ebx
 push eax
 push esi
 call ReadProcessMemory
 test eax,eax
 jz @loc_731B155D
 mov eax,dword ptr [ebp+00Ch]
 cmp [ebx+018h],eax
 jz @loc_731B1568
 mov eax,dword ptr [ebx+008h]
 mov dword ptr [ebp-004h],eax
 cmp eax,edi
 jnz @loc_731B152C

@loc_731B1555:
 push 006h

@loc_731B1557:
 call SetLastError

@loc_731B155D:
 xor eax,eax

@loc_731B155F:
 pop edi
 pop esi
 pop ebx
 mov esp,ebp
 pop ebp
 ret 0000Ch
@loc_731B1568:
 mov eax,001h
 jmp @loc_731B155F
end;

function GetModuleBaseNameW(AProcess:THandle;AModule:HMODULE;AProcessName:PWChar;ASizeOfName:Cardinal):Cardinal; stdcall; assembler;
asm
 pop ebp                                //fucking delphi call

 push ebp
 mov ebp,esp
 sub esp,048h
 push esi
 lea eax,dword ptr [ebp-048h]
 push eax
 push dword ptr [ebp+00Ch]
 push dword ptr [ebp+008h]
 call sub_731B14A5
 test eax,eax
 jnz @loc_731B1793
 xor eax,eax
 jmp @loc_731B17CB

@loc_731B1793:
 movzx esi,word ptr [ebp-01Ah]
 mov eax,dword ptr [ebp+014h]
 add eax,eax
 cmp esi,eax
 jbe @loc_731B17A2
 mov esi,eax

@loc_731B17A2:
 push 000h
 push esi
 push dword ptr [ebp+010h]
 push dword ptr [ebp-018h]
 push dword ptr [ebp+008h]
 call ReadProcessMemory
 test eax,eax
 jnz @loc_731B17BC
 xor eax,eax
 jmp @loc_731B17CB

@loc_731B17BC:
 movzx eax,word ptr [ebp-01Ah]
 cmp eax,esi
 jnz @loc_731B17C7 
 sub esi,002h

@loc_731B17C7:
 mov eax,esi
 shr eax,001h

@loc_731B17CB:
 pop esi
 mov esp,ebp
 pop ebp
 ret 00010h
end;

function GetModuleBaseNameA(AProcess:THandle;AModule:HMODULE;AProcessName:PChar;ASizeOfName:Cardinal):Cardinal; stdcall; assembler;
asm
 pop ebp                                //fucking delphi call

 push ebx
 push esi
 mov esi,dword ptr [esp+018h]
 push edi
 push ebp
 lea eax,ds:000000000 [esi*002h]
 push eax
 push 000h
 call LocalAlloc
 mov edi,eax
 test edi,edi
 jnz @loc_731B17F4
 xor eax,eax
 jmp @loc_731B1830

@loc_731B17F4:
 push esi
 push edi
 push dword ptr [esp+020h]
 push dword ptr [esp+020h]
 call GetModuleBaseNameW
 mov ecx,eax
 cmp eax,esi
 mov ebx,eax
 jnb @loc_731B180E
 lea ecx,dword ptr [ebx+001h]

@loc_731B180E:
 xor ebp,ebp
 push ebp
 push ebp
 push esi
 push dword ptr [esp+028h]
 push ecx
 push edi
 push ebp
 push ebp
 call WideCharToMultiByte
 test eax,eax
 jnz @loc_731B1827
 xor ebx,ebx

@loc_731B1827:
 push edi
 call LocalFree
 mov eax,ebx

@loc_731B1830:
 pop ebp
 pop edi
 pop esi
 pop ebx
 ret 00010h
end;

function ModuleName2PID(AName:string):Cardinal;
var
 LI:Integer;
 LProcessesID:array[1..1024] of Cardinal;
 LDone,LProcesses,LPID:Cardinal;
 LModuleHandle:HMODULE;
 LProcessHandle:THandle;
 LProcessName:array[0..MAX_PATH-1] of Char;
 LProcNameStr:string;

begin
 AName:=UpCase(AName);
 if not Boolean(EnumProcesses(@LProcessesID,SizeOf(LProcessesID),@LDone)) then
 begin
  Result:=$FFFFFFFF;
  Exit;
 end;
 LProcesses:=LDone div SizeOf(Cardinal);
 for LI:=0 to LProcesses-1 do
 begin
  LProcessName:='unknown';
  LPID:=LProcessesID[LI];
  LProcessHandle:=OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ,False,LPID);
  if LProcessHandle=0 then Continue;
  if Boolean(EnumProcessModules(LProcessHandle,@LModuleHandle,SizeOf(LModuleHandle),@LDone)) then
  begin
   GetModuleBaseNameA(LProcessHandle,LModuleHandle,LProcessName,SizeOf(LProcessName));
   LProcNameStr:=UpCase(LProcessName);
  end;
  CloseHandle(LProcessHandle);
  if LProcNameStr=AName then
  begin
   Result:=LPID;
   Exit;
  end;
 end;
 Result:=0;
end;

function EnableDebugPrivilege:Boolean;
var
 TokenHandle:THandle;
 DebugNameValue:TLargeInteger;
 Privileges:TOKEN_PRIVILEGES;
 RetLen:Cardinal;
begin
 Result:=False;
 if not OpenProcessToken(GetCurrentProcess,TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY,TokenHandle) then Exit;
 if not LookupPrivilegeValue(nil,'SeDebugPrivilege',DebugNameValue) then
 begin
  CloseHandle(TokenHandle);
  Exit;
 end;
 Privileges.PrivilegeCount:=1;
 Privileges.Privileges[0].Luid:=DebugNameValue;
 Privileges.Privileges[0].Attributes:=SE_PRIVILEGE_ENABLED;
 Result:=AdjustTokenPrivileges(TokenHandle,False,Privileges,SizeOf(Privileges),nil,RetLen);
 CloseHandle(TokenHandle);
end;


end.

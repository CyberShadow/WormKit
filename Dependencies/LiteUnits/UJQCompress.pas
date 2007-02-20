unit UJQCompress;

interface
uses Windows;

function JQCompress(ACompressedOutput,AInputBuffer:Pointer;AInputLength:Cardinal):Cardinal;
function JQDecompress(ADecompressedOutput,AInputBuffer:Pointer;AInputLength:Cardinal):Cardinal;

implementation


function JQCompressProc(ACompressedOutput,AInputBuffer:Pointer;AInputLength:Cardinal;AWorkMem:Pointer):Integer;assembler;stdcall;
asm
 pop ebp
 @jq_encode:    sub     edx, edx                //;Encoder/Encryptor
                xchg    eax, edx
                pushad
                mov     ebp, esp
                and     ecx, eax
                mov     edi, [ebp+30h]
                cld
                mov     ch, 40h
                push    edi
                rep     stosd
                sub     edx, 2864E25Ch
                mov     esi, [ebp+28h]
                jnz     @jq_e0
                dec     edx
         @jq_e0: push    ecx
                sub     ax, 0AEB6h
                mov     edi, [ebp+24h]
                pop     ebx
                stosw
                xchg    eax, edx
                pop     ebp
                stosd
                push    edi
                xchg    eax, edx
                push    esp
         @jq_e1: test    cl, 7
                lodsb
                jnz     @jq_e3
                xchg    edx, [esp]
                adc     ah, dl
                pop     edx
                xchg    edi, [esp]
                ror     edx, 1
                mov     [edi], ah
                jc      @jq_e2
                xor     edx, 2C047C3Eh
         @jq_e2: pop     edi
                mov     ah, 0FFh
                push    edi
                xor     edx, 76C52B8Dh
                inc     edi
                push    edx
         @jq_e3: cmp     al, [ebx+ebp]
                jz      @jq_e5
                ror     edx, 1
                mov     [ebx+ebp], al
                jnc     @jq_e4
                xor     edx, 2C047C3Eh
         @jq_e4: mov     bh, al
                xor     edx, 5AC157B3h
                adc     al, dl
                stosb
                mov     al, bh
                stc
         @jq_e5: inc     ecx
                mov     bh, bl
                rcl     ah, 1
                cmp     ecx, [esp+34h]
                mov     bl, al
                jc      @jq_e1
                ror     ah, cl
                pop     ebx
                add     ah, bl
                pop     esi
                mov     ebp, esp
                sub     edi, [ebp+24h]
                mov     [ebp+14h], edx
                xchg    ah, [esi]
                add     [ebp+1Ch], edi
                popad
                ret     10h
end;

function JQDecompressProc(ADecompressedOutput,AInputBuffer:Pointer;AInputLength:Cardinal;AWorkMem:Pointer):Integer;assembler;stdcall;
asm
 pop ebp

@jq_decode:     sub     eax, eax                //;Decoder/Decryptor
                pushad
                mov     ebp, esp
                and     ecx, eax
                mov     edi, [ebp+30h]
                cld
                mov     ch, 40h
                push    edi
                rep     stosd
                mov     esi, [ebp+28h]
                xchg    ebx, eax
                add     ecx, [ebp+2Ch]
                lodsw
                mov     edi, [ebp+24h]
                add     ecx,-6
                pop     ebp
                lodsd
                xchg    eax, edx
         @jq_d0: test    byte ptr [esp+1Ch], 7
                jnz     @jq_d2
                ror     edx, 1
                jecxz   @jq_d5
                jnc     @jq_d1
                xor     edx, 2C047C3Eh
         @jq_d1: lodsb
                dec     ecx
                xor     edx, 5AC157B3h
                sbb     al, dl
                mov     ah, al
         @jq_d2: shl     ah, 1
                inc     byte ptr [esp+1Ch]
                jnc     @jq_d4
                ror     edx, 1
                jecxz   @jq_d5
                jc      @jq_d3
                xor     edx, 2C047C3Eh
         @jq_d3: lodsb
                dec     ecx
                xor     edx, 76C52B8Dh
                sbb     al, dl
                mov     [ebx+ebp], al
         @jq_d4: mov     al, [ebx+ebp]
                mov     bh, bl
                stosb
                mov     bl, al
                jmp     @jq_d0
                dec     edx
                push    ecx
         @jq_d5: sub     edi, [esp+24h]
                mov     [esp+1Ch], edi
                popad
                ret     10h
end;


function JQCompress(ACompressedOutput,AInputBuffer:Pointer;AInputLength:Cardinal):Cardinal;
var
 LMem:Pointer;
begin
 LMem:=VirtualAlloc(nil,$100000,MEM_COMMIT,PAGE_READWRITE);
 Result:=JQCompressProc(ACompressedOutput,AInputBuffer,AInputLength,LMem);
 VirtualFree(LMem,0,MEM_RELEASE);
end;

function JQDecompress(ADecompressedOutput,AInputBuffer:Pointer;AInputLength:Cardinal):Cardinal;
var
 LMem:Pointer;
begin
 LMem:=VirtualAlloc(nil,$100000,MEM_COMMIT,PAGE_READWRITE);
 Result:=JQDecompressProc(ADecompressedOutput,AInputBuffer,AInputLength,LMem);
 VirtualFree(LMem,0,MEM_RELEASE);
end;

end.

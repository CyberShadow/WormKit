#include <windows.h>

BOOLEAN WINAPI DllMain( IN HINSTANCE hDllHandle, IN DWORD     nReason,  IN LPVOID    Reserved )
{
	if (nReason == DLL_PROCESS_ATTACH)
	{
		char *p = (char*)0x400000;
		for (; strcmp(p, "PASS %s \r\n"); p++);
		DWORD oldProtect;
		VirtualProtect(p, 32, PAGE_READWRITE, &oldProtect);
		strcpy(p+7, p+8);

		p = (char*)0x400000;
		for (; strcmp(p, "Username"); p++);
		VirtualProtect(p, 8, PAGE_READWRITE, &oldProtect);
		p[4] = 'l';
	}
	return TRUE;
}

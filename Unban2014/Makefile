wkUnban2014.dll : wkUnban2014.obj Makefile
	link /nologo /DLL /ENTRY:DllMain /NODEFAULTLIB /SUBSYSTEM:WINDOWS /MERGE:.text=.wormkit /MERGE:.rdata=.wormkit /MERGE:.data=.wormkit /SECTION:.wormkit,ERW wkUnban2014.obj user32.lib kernel32.lib msvcrt.lib advapi32.lib
#	ulink -Tpd wkUnban2014.obj msvcrt.lib -e_DllMain@12 kernel32.lib user32.lib
wkUnban2014.obj : wkUnban2014.cpp
	cl /nologo /c /O1 /GS- wkUnban2014.cpp

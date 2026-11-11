unit uSqliteWinEmbedBridge;

{$mode objfpc}{$H+}

{ Satisfies undefined symbols from MSVC-built sqlite3_embed.o for FPC 3.2.x internal linker. }

interface

implementation

uses
  Windows, ctypes;

var
  __ImageBase: Pointer; public name '__ImageBase';
  __isa_available: LongInt; public name '__isa_available';

var
  __imp__beginthreadex: Pointer; public name '__imp__beginthreadex';
  __imp__endthreadex: Pointer; public name '__imp__endthreadex';
  __imp__localtime64_s: Pointer; public name '__imp__localtime64_s';
  __imp__msize: Pointer; public name '__imp__msize';
  __imp_CloseHandle: Pointer; public name '__imp_CloseHandle';
  __imp_DeleteCriticalSection: Pointer; public name '__imp_DeleteCriticalSection';
  __imp_EnterCriticalSection: Pointer; public name '__imp_EnterCriticalSection';
  __imp_free: Pointer; public name '__imp_free';
  __imp_GetCurrentThreadId: Pointer; public name '__imp_GetCurrentThreadId';
  __imp_InitializeCriticalSection: Pointer; public name '__imp_InitializeCriticalSection';
  __imp_LeaveCriticalSection: Pointer; public name '__imp_LeaveCriticalSection';
  __imp_malloc: Pointer; public name '__imp_malloc';
  __imp_RaiseException: Pointer; public name '__imp_RaiseException';
  __imp_realloc: Pointer; public name '__imp_realloc';
  __imp_strcspn: Pointer; public name '__imp_strcspn';
  __imp_strspn: Pointer; public name '__imp_strspn';
  __imp_TryEnterCriticalSection: Pointer; public name '__imp_TryEnterCriticalSection';

function ucrt_malloc(size: size_t): Pointer; cdecl; external 'ucrtbase.dll' name 'malloc';
procedure ucrt_free(ptr: Pointer); cdecl; external 'ucrtbase.dll' name 'free';
function ucrt_realloc(ptr: Pointer; size: size_t): Pointer; cdecl; external 'ucrtbase.dll' name 'realloc';
function ucrt__msize(ptr: Pointer): size_t; cdecl; external 'ucrtbase.dll' name '_msize';
function ucrt__localtime64_s(tm: Pointer; time64: Int64): cint; cdecl; external 'ucrtbase.dll' name '_localtime64_s';
function ucrt__beginthreadex(security: Pointer; stack: Cardinal; func: Pointer; arg: Pointer;
  flags: Cardinal; id: PCardinal): Cardinal; cdecl; external 'ucrtbase.dll' name '_beginthreadex';
procedure ucrt__endthreadex(code: Cardinal); cdecl; external 'ucrtbase.dll' name '_endthreadex';
function ucrt_memchr(p: Pointer; c: cint; n: size_t): Pointer; cdecl; external 'ucrtbase.dll' name 'memchr';
function ucrt_memcmp(p1, p2: Pointer; n: size_t): cint; cdecl; external 'ucrtbase.dll' name 'memcmp';
function ucrt_memcpy(dest, src: Pointer; n: size_t): Pointer; cdecl; external 'ucrtbase.dll' name 'memcpy';
function ucrt_memmove(dest, src: Pointer; n: size_t): Pointer; cdecl; external 'ucrtbase.dll' name 'memmove';
function ucrt_memset(p: Pointer; c: cint; n: size_t): Pointer; cdecl; external 'ucrtbase.dll' name 'memset';
function ucrt_strchr(s: PAnsiChar; c: cint): PAnsiChar; cdecl; external 'ucrtbase.dll' name 'strchr';
function ucrt_strcmp(s1, s2: PAnsiChar): cint; cdecl; external 'ucrtbase.dll' name 'strcmp';
function ucrt_strncmp(s1, s2: PAnsiChar; n: size_t): cint; cdecl; external 'ucrtbase.dll' name 'strncmp';
function ucrt_strrchr(s: PAnsiChar; c: cint): PAnsiChar; cdecl; external 'ucrtbase.dll' name 'strrchr';
function ucrt_strcspn(s1, s2: PAnsiChar): size_t; cdecl; external 'ucrtbase.dll' name 'strcspn';
function ucrt_strspn(s1, s2: PAnsiChar): size_t; cdecl; external 'ucrtbase.dll' name 'strspn';
function ucrt_log(x: Double): Double; cdecl; external 'ucrtbase.dll' name 'log';

function Lca_malloc(size: size_t): Pointer; cdecl; public name 'malloc';
begin
  Result := ucrt_malloc(size);
end;

procedure Lca_free(ptr: Pointer); cdecl; public name 'free';
begin
  ucrt_free(ptr);
end;

function Lca_realloc(ptr: Pointer; size: size_t): Pointer; cdecl; public name 'realloc';
begin
  Result := ucrt_realloc(ptr, size);
end;

function Lca__msize(ptr: Pointer): size_t; cdecl; public name '_msize';
begin
  Result := ucrt__msize(ptr);
end;

function Lca__localtime64_s(tm: Pointer; time64: Int64): cint; cdecl; public name '_localtime64_s';
begin
  Result := ucrt__localtime64_s(tm, time64);
end;

function Lca__beginthreadex(security: Pointer; stack: Cardinal; func: Pointer; arg: Pointer;
  flags: Cardinal; id: PCardinal): Cardinal; cdecl; public name '_beginthreadex';
begin
  Result := ucrt__beginthreadex(security, stack, func, arg, flags, id);
end;

procedure Lca__endthreadex(code: Cardinal); cdecl; public name '_endthreadex';
begin
  ucrt__endthreadex(code);
end;

function Lca_memchr(p: Pointer; c: cint; n: size_t): Pointer; cdecl; public name 'memchr';
begin Result := ucrt_memchr(p, c, n); end;
function Lca_memcmp(p1, p2: Pointer; n: size_t): cint; cdecl; public name 'memcmp';
begin Result := ucrt_memcmp(p1, p2, n); end;
function Lca_memcpy(dest, src: Pointer; n: size_t): Pointer; cdecl; public name 'memcpy';
begin Result := ucrt_memcpy(dest, src, n); end;
function Lca_memmove(dest, src: Pointer; n: size_t): Pointer; cdecl; public name 'memmove';
begin Result := ucrt_memmove(dest, src, n); end;
function Lca_memset(p: Pointer; c: cint; n: size_t): Pointer; cdecl; public name 'memset';
begin Result := ucrt_memset(p, c, n); end;
function Lca_strchr(s: PAnsiChar; c: cint): PAnsiChar; cdecl; public name 'strchr';
begin Result := ucrt_strchr(s, c); end;
function Lca_strcmp(s1, s2: PAnsiChar): cint; cdecl; public name 'strcmp';
begin Result := ucrt_strcmp(s1, s2); end;
function Lca_strncmp(s1, s2: PAnsiChar; n: size_t): cint; cdecl; public name 'strncmp';
begin Result := ucrt_strncmp(s1, s2, n); end;
function Lca_strrchr(s: PAnsiChar; c: cint): PAnsiChar; cdecl; public name 'strrchr';
begin Result := ucrt_strrchr(s, c); end;
function Lca_strcspn(s1, s2: PAnsiChar): size_t; cdecl; public name 'strcspn';
begin Result := ucrt_strcspn(s1, s2); end;
function Lca_strspn(s1, s2: PAnsiChar): size_t; cdecl; public name 'strspn';
begin Result := ucrt_strspn(s1, s2); end;
function Lca_log(x: Double): Double; cdecl; public name 'log';
begin Result := ucrt_log(x); end;

function Lca_AreFileApisANSI: BOOL; stdcall; public name 'AreFileApisANSI';
begin Result := Windows.AreFileApisANSI; end;
function Lca_CloseHandle(hObject: THandle): BOOL; stdcall; public name 'CloseHandle';
begin Result := Windows.CloseHandle(hObject); end;
function Lca_CreateFileA(lpFileName: PAnsiChar; dwDesiredAccess, dwShareMode: DWORD;
  lpSecurity: Pointer; dwCreationDisposition, dwFlagsAndAttributes: DWORD;
  hTemplateFile: THandle): THandle; stdcall; public name 'CreateFileA';
begin
  Result := Windows.CreateFileA(lpFileName, dwDesiredAccess, dwShareMode, lpSecurity,
    dwCreationDisposition, dwFlagsAndAttributes, hTemplateFile);
end;
function Lca_CreateFileMappingW(hFile: THandle; lpFileMappingAttributes: Pointer;
  flProtect: DWORD; dwMaximumSizeHigh, dwMaximumSizeLow: DWORD;
  lpName: PWideChar): THandle; stdcall; public name 'CreateFileMappingW';
begin
  Result := Windows.CreateFileMappingW(hFile, lpFileMappingAttributes, flProtect,
    dwMaximumSizeHigh, dwMaximumSizeLow, lpName);
end;
function Lca_CreateFileMappingA(hFile: THandle; lpFileMappingAttributes: Pointer;
  flProtect: DWORD; dwMaximumSizeHigh, dwMaximumSizeLow: DWORD;
  lpName: PAnsiChar): THandle; stdcall; public name 'CreateFileMappingA';
begin
  Result := Windows.CreateFileMappingA(hFile, lpFileMappingAttributes, flProtect,
    dwMaximumSizeHigh, dwMaximumSizeLow, lpName);
end;
function Lca_GetVersionExA(var lpVersionInformation: TOSVersionInfoA): BOOL; stdcall;
  public name 'GetVersionExA';
begin Result := Windows.GetVersionExA(lpVersionInformation); end;
function Lca_GetVersionExW(var lpVersionInformation: TOSVersionInfoW): BOOL; stdcall;
  public name 'GetVersionExW';
begin Result := Windows.GetVersionExW(lpVersionInformation); end;
function ucrt_strlen(s: PAnsiChar): size_t; cdecl; external 'ucrtbase.dll' name 'strlen';
function ucrt_localtime64(time64: PInt64; tm: Pointer): PAnsiChar; cdecl;
  external 'ucrtbase.dll' name '_localtime64';
function Lca_strlen(s: PAnsiChar): size_t; cdecl; public name 'strlen';
begin Result := ucrt_strlen(s); end;
function Lca__localtime64(time64: PInt64; tm: Pointer): PAnsiChar; cdecl; public name '_localtime64';
begin Result := ucrt_localtime64(time64, tm); end;
function Lca_CreateFileW(lpFileName: PWideChar; dwDesiredAccess, dwShareMode: DWORD;
  lpSecurity: Pointer; dwCreationDisposition, dwFlagsAndAttributes: DWORD;
  hTemplateFile: THandle): THandle; stdcall; public name 'CreateFileW';
begin
  Result := Windows.CreateFileW(lpFileName, dwDesiredAccess, dwShareMode, lpSecurity,
    dwCreationDisposition, dwFlagsAndAttributes, hTemplateFile);
end;
function Lca_CreateMutexW(lpMutexAttributes: Pointer; bInitialOwner: BOOL;
  lpName: PWideChar): THandle; stdcall; public name 'CreateMutexW';
begin Result := Windows.CreateMutexW(lpMutexAttributes, bInitialOwner, lpName); end;
function Lca_DeleteFileA(lpFileName: PAnsiChar): BOOL; stdcall; public name 'DeleteFileA';
begin Result := Windows.DeleteFileA(lpFileName); end;
function Lca_DeleteFileW(lpFileName: PWideChar): BOOL; stdcall; public name 'DeleteFileW';
begin Result := Windows.DeleteFileW(lpFileName); end;
function Lca_FlushFileBuffers(hFile: THandle): BOOL; stdcall; public name 'FlushFileBuffers';
begin Result := Windows.FlushFileBuffers(hFile); end;
function Lca_FlushViewOfFile(lpBaseAddress: Pointer; dwNumberOfBytesToFlush: SIZE_T): BOOL;
  stdcall; public name 'FlushViewOfFile';
begin Result := Windows.FlushViewOfFile(lpBaseAddress, dwNumberOfBytesToFlush); end;
function Lca_FormatMessageA(dwFlags: DWORD; lpSource: Pointer; dwMessageId: DWORD;
  dwLanguageId: DWORD; lpBuffer: PAnsiChar; nSize: DWORD; Arguments: Pointer): DWORD;
  stdcall; public name 'FormatMessageA';
begin
  Result := Windows.FormatMessageA(dwFlags, lpSource, dwMessageId, dwLanguageId,
    lpBuffer, nSize, Arguments);
end;
function Lca_FormatMessageW(dwFlags: DWORD; lpSource: Pointer; dwMessageId: DWORD;
  dwLanguageId: DWORD; lpBuffer: PWideChar; nSize: DWORD; Arguments: Pointer): DWORD;
  stdcall; public name 'FormatMessageW';
begin
  Result := Windows.FormatMessageW(dwFlags, lpSource, dwMessageId, dwLanguageId,
    lpBuffer, nSize, Arguments);
end;
function Lca_FreeLibrary(hLibModule: THandle): BOOL; stdcall; public name 'FreeLibrary';
begin Result := Windows.FreeLibrary(hLibModule); end;
function Lca_GetCurrentProcessId: DWORD; stdcall; public name 'GetCurrentProcessId';
begin Result := Windows.GetCurrentProcessId; end;
function Lca_GetCurrentThreadId: DWORD; stdcall; public name 'GetCurrentThreadId';
begin Result := Windows.GetCurrentThreadId; end;
function Lca_GetDiskFreeSpaceA(lpRootPathName: PAnsiChar; var lpSectorsPerCluster,
  lpBytesPerSector, lpNumberOfFreeClusters, lpTotalNumberOfClusters: DWORD): BOOL;
  stdcall; public name 'GetDiskFreeSpaceA';
begin
  Result := Windows.GetDiskFreeSpaceA(lpRootPathName, lpSectorsPerCluster, lpBytesPerSector,
    lpNumberOfFreeClusters, lpTotalNumberOfClusters);
end;
function Lca_GetDiskFreeSpaceW(lpRootPathName: PWideChar; var lpSectorsPerCluster,
  lpBytesPerSector, lpNumberOfFreeClusters, lpTotalNumberOfClusters: DWORD): BOOL;
  stdcall; public name 'GetDiskFreeSpaceW';
begin
  Result := Windows.GetDiskFreeSpaceW(lpRootPathName, lpSectorsPerCluster, lpBytesPerSector,
    lpNumberOfFreeClusters, lpTotalNumberOfClusters);
end;
function Lca_GetFileAttributesA(lpFileName: PAnsiChar): DWORD; stdcall; public name 'GetFileAttributesA';
begin Result := Windows.GetFileAttributesA(lpFileName); end;
function Lca_GetFileAttributesExW(lpFileName: PWideChar; fInfoLevelId: GET_FILEEX_INFO_LEVELS;
  lpFileInformation: Pointer): BOOL; stdcall; public name 'GetFileAttributesExW';
begin Result := Windows.GetFileAttributesExW(lpFileName, fInfoLevelId, lpFileInformation); end;
function Lca_GetFileAttributesW(lpFileName: PWideChar): DWORD; stdcall; public name 'GetFileAttributesW';
begin Result := Windows.GetFileAttributesW(lpFileName); end;
function Lca_GetFileSize(hFile: THandle; lpFileSizeHigh: PDWORD): DWORD; stdcall; public name 'GetFileSize';
begin Result := Windows.GetFileSize(hFile, lpFileSizeHigh); end;
function Lca_GetFullPathNameA(lpFileName: PAnsiChar; nBufferLength: DWORD; lpBuffer: PAnsiChar;
  var lpFilePart: PAnsiChar): DWORD; stdcall; public name 'GetFullPathNameA';
begin Result := Windows.GetFullPathNameA(lpFileName, nBufferLength, lpBuffer, lpFilePart); end;
function Lca_GetFullPathNameW(lpFileName: PWideChar; nBufferLength: DWORD; lpBuffer: PWideChar;
  var lpFilePart: PWideChar): DWORD; stdcall; public name 'GetFullPathNameW';
begin Result := Windows.GetFullPathNameW(lpFileName, nBufferLength, lpBuffer, lpFilePart); end;
function Lca_GetLastError: DWORD; stdcall; public name 'GetLastError';
begin Result := Windows.GetLastError; end;
function Lca_GetProcAddress(hModule: HMODULE; lpProcName: PAnsiChar): Pointer; stdcall;
  public name 'GetProcAddress';
begin Result := Windows.GetProcAddress(hModule, lpProcName); end;
function Lca_GetProcessHeap: THandle; stdcall; public name 'GetProcessHeap';
begin Result := Windows.GetProcessHeap; end;
procedure Lca_GetSystemInfo(lpSystemInfo: PSystemInfo); stdcall; public name 'GetSystemInfo';
begin Windows.GetSystemInfo(lpSystemInfo); end;
procedure Lca_GetSystemTime(var lpSystemTime: TSystemTime); stdcall; public name 'GetSystemTime';
begin Windows.GetSystemTime(lpSystemTime); end;
procedure Lca_GetSystemTimeAsFileTime(var lpFileTime: TFileTime); stdcall;
  public name 'GetSystemTimeAsFileTime';
begin Windows.GetSystemTimeAsFileTime(lpFileTime); end;
function Lca_GetTempPathA(nBufferLength: DWORD; lpBuffer: PAnsiChar): DWORD; stdcall;
  public name 'GetTempPathA';
begin Result := Windows.GetTempPathA(nBufferLength, lpBuffer); end;
function Lca_GetTempPathW(nBufferLength: DWORD; lpBuffer: PWideChar): DWORD; stdcall;
  public name 'GetTempPathW';
begin Result := Windows.GetTempPathW(nBufferLength, lpBuffer); end;
function Lca_GetTickCount: DWORD; stdcall; public name 'GetTickCount';
begin Result := Windows.GetTickCount; end;
function Lca_HeapAlloc(hHeap: THandle; dwFlags: DWORD; dwBytes: SIZE_T): Pointer; stdcall;
  public name 'HeapAlloc';
begin Result := Windows.HeapAlloc(hHeap, dwFlags, dwBytes); end;
function Lca_HeapCompact(hHeap: THandle; dwFlags: DWORD): SIZE_T; stdcall; public name 'HeapCompact';
begin Result := Windows.HeapCompact(hHeap, dwFlags); end;
function Lca_HeapCreate(flOptions: DWORD; dwInitialSize, dwMaximumSize: SIZE_T): THandle;
  stdcall; public name 'HeapCreate';
begin Result := Windows.HeapCreate(flOptions, dwInitialSize, dwMaximumSize); end;
function Lca_HeapDestroy(hHeap: THandle): BOOL; stdcall; public name 'HeapDestroy';
begin Result := Windows.HeapDestroy(hHeap); end;
function Lca_HeapFree(hHeap: THandle; dwFlags: DWORD; lpMem: Pointer): BOOL; stdcall;
  public name 'HeapFree';
begin Result := Windows.HeapFree(hHeap, dwFlags, lpMem); end;
function Lca_HeapReAlloc(hHeap: THandle; dwFlags: DWORD; lpMem: Pointer; dwBytes: SIZE_T): Pointer;
  stdcall; public name 'HeapReAlloc';
begin Result := Windows.HeapReAlloc(hHeap, dwFlags, lpMem, dwBytes); end;
function Lca_HeapSize(hHeap: THandle; dwFlags: DWORD; lpMem: Pointer): SIZE_T; stdcall;
  public name 'HeapSize';
begin Result := Windows.HeapSize(hHeap, dwFlags, lpMem); end;
function Lca_HeapValidate(hHeap: THandle; dwFlags: DWORD; lpMem: Pointer): BOOL; stdcall;
  public name 'HeapValidate';
begin Result := Windows.HeapValidate(hHeap, dwFlags, lpMem); end;
function Lca_LoadLibraryA(lpLibFileName: PAnsiChar): HMODULE; stdcall; public name 'LoadLibraryA';
begin Result := Windows.LoadLibraryA(lpLibFileName); end;
function Lca_LoadLibraryW(lpLibFileName: PWideChar): HMODULE; stdcall; public name 'LoadLibraryW';
begin Result := Windows.LoadLibraryW(lpLibFileName); end;
function Lca_LocalFree(hMem: HLOCAL): HLOCAL; stdcall; public name 'LocalFree';
begin Result := Windows.LocalFree(hMem); end;
function Lca_LockFile(hFile: THandle; dwFileOffsetLow, dwFileOffsetHigh, nNumberOfBytesToLockLow,
  nNumberOfBytesToLockHigh: DWORD): BOOL; stdcall; public name 'LockFile';
begin
  Result := Windows.LockFile(hFile, dwFileOffsetLow, dwFileOffsetHigh,
    nNumberOfBytesToLockLow, nNumberOfBytesToLockHigh);
end;
function Lca_LockFileEx(hFile: THandle; dwFlags, dwReserved: DWORD; nNumberOfBytesToLockLow,
  nNumberOfBytesToLockHigh: DWORD; var lpOverlapped: TOverlapped): BOOL; stdcall;
  public name 'LockFileEx';
begin
  Result := Windows.LockFileEx(hFile, dwFlags, dwReserved, nNumberOfBytesToLockLow,
    nNumberOfBytesToLockHigh, lpOverlapped);
end;
function Lca_MapViewOfFile(hFileMappingObject: THandle; dwDesiredAccess: DWORD;
  dwFileOffsetHigh, dwFileOffsetLow, dwNumberOfBytesToMap: SIZE_T): Pointer; stdcall;
  public name 'MapViewOfFile';
begin
  Result := Windows.MapViewOfFile(hFileMappingObject, dwDesiredAccess, dwFileOffsetHigh,
    dwFileOffsetLow, dwNumberOfBytesToMap);
end;
function Lca_MultiByteToWideChar(CodePage: UINT; dwFlags: DWORD; lpMultiByteStr: PAnsiChar;
  cbMultiByte: Integer; lpWideCharStr: PWideChar; cchWideChar: Integer): Integer; stdcall;
  public name 'MultiByteToWideChar';
begin
  Result := Windows.MultiByteToWideChar(CodePage, dwFlags, lpMultiByteStr, cbMultiByte,
    lpWideCharStr, cchWideChar);
end;
procedure Lca_OutputDebugStringA(lpOutputString: PAnsiChar); stdcall; public name 'OutputDebugStringA';
begin Windows.OutputDebugStringA(lpOutputString); end;
procedure Lca_OutputDebugStringW(lpOutputString: PWideChar); stdcall; public name 'OutputDebugStringW';
begin Windows.OutputDebugStringW(lpOutputString); end;
function Lca_QueryPerformanceCounter(var lpPerformanceCount: Int64): BOOL; stdcall;
  public name 'QueryPerformanceCounter';
begin Result := Windows.QueryPerformanceCounter(lpPerformanceCount); end;
function Lca_ReadFile(hFile: THandle; var lpBuffer; nNumberOfBytesToRead: DWORD;
  var lpNumberOfBytesRead: DWORD; lpOverlapped: POverlapped): BOOL; stdcall; public name 'ReadFile';
begin
  Result := Windows.ReadFile(hFile, lpBuffer, nNumberOfBytesToRead, lpNumberOfBytesRead, lpOverlapped);
end;
function Lca_SetEndOfFile(hFile: THandle): BOOL; stdcall; public name 'SetEndOfFile';
begin Result := Windows.SetEndOfFile(hFile); end;
function Lca_SetFilePointer(hFile: THandle; lDistanceToMove: LongInt;
  lpDistanceToMoveHigh: PLongInt; dwMoveMethod: DWORD): DWORD; stdcall; public name 'SetFilePointer';
begin Result := Windows.SetFilePointer(hFile, lDistanceToMove, lpDistanceToMoveHigh, dwMoveMethod); end;
procedure Lca_Sleep(dwMilliseconds: DWORD); stdcall; public name 'Sleep';
begin Windows.Sleep(dwMilliseconds); end;
function Lca_SystemTimeToFileTime(const lpSystemTime: TSystemTime; var lpFileTime: TFileTime): BOOL;
  stdcall; public name 'SystemTimeToFileTime';
begin Result := Windows.SystemTimeToFileTime(lpSystemTime, lpFileTime); end;
function Lca_UnlockFile(hFile: THandle; dwFileOffsetLow, dwFileOffsetHigh,
  nNumberOfBytesToUnlockLow, nNumberOfBytesToUnlockHigh: DWORD): BOOL; stdcall; public name 'UnlockFile';
begin
  Result := Windows.UnlockFile(hFile, dwFileOffsetLow, dwFileOffsetHigh,
    nNumberOfBytesToUnlockLow, nNumberOfBytesToUnlockHigh);
end;
function Lca_UnlockFileEx(hFile: THandle; dwReserved: DWORD; nNumberOfBytesToUnlockLow,
  nNumberOfBytesToUnlockHigh: DWORD; var lpOverlapped: TOverlapped): BOOL; stdcall;
  public name 'UnlockFileEx';
begin
  Result := Windows.UnlockFileEx(hFile, dwReserved, nNumberOfBytesToUnlockLow,
    nNumberOfBytesToUnlockHigh, lpOverlapped);
end;
function Lca_UnmapViewOfFile(lpBaseAddress: Pointer): BOOL; stdcall; public name 'UnmapViewOfFile';
begin Result := Windows.UnmapViewOfFile(lpBaseAddress); end;
function Lca_WaitForSingleObject(hHandle: THandle; dwMilliseconds: DWORD): DWORD; stdcall;
  public name 'WaitForSingleObject';
begin Result := Windows.WaitForSingleObject(hHandle, dwMilliseconds); end;
function Lca_WaitForSingleObjectEx(hHandle: THandle; dwMilliseconds: DWORD; bAlertable: BOOL): DWORD;
  stdcall; public name 'WaitForSingleObjectEx';
begin Result := Windows.WaitForSingleObjectEx(hHandle, dwMilliseconds, bAlertable); end;
function Lca_WideCharToMultiByte(CodePage: UINT; dwFlags: DWORD; lpWideCharStr: PWideChar;
  cchWideChar: Integer; lpMultiByteStr: PAnsiChar; cbMultiByte: Integer; lpDefaultChar: PAnsiChar;
  lpUsedDefaultChar: PBOOL): Integer; stdcall; public name 'WideCharToMultiByte';
begin
  Result := Windows.WideCharToMultiByte(CodePage, dwFlags, lpWideCharStr, cchWideChar,
    lpMultiByteStr, cbMultiByte, lpDefaultChar, lpUsedDefaultChar);
end;
function Lca_WriteFile(hFile: THandle; const lpBuffer; nNumberOfBytesToWrite: DWORD;
  var lpNumberOfBytesWritten: DWORD; lpOverlapped: POverlapped): BOOL; stdcall; public name 'WriteFile';
begin
  Result := Windows.WriteFile(hFile, lpBuffer, nNumberOfBytesToWrite, lpNumberOfBytesWritten, lpOverlapped);
end;

procedure Lca_InitializeCriticalSection(lpCriticalSection: PRTLCriticalSection); winapi;
  public name 'InitializeCriticalSection';
begin Windows.InitializeCriticalSection(lpCriticalSection); end;
procedure Lca_EnterCriticalSection(lpCriticalSection: PRTLCriticalSection); winapi;
  public name 'EnterCriticalSection';
begin Windows.EnterCriticalSection(lpCriticalSection); end;
procedure Lca_LeaveCriticalSection(lpCriticalSection: PRTLCriticalSection); winapi;
  public name 'LeaveCriticalSection';
begin Windows.LeaveCriticalSection(lpCriticalSection); end;
procedure Lca_DeleteCriticalSection(lpCriticalSection: PRTLCriticalSection); winapi;
  public name 'DeleteCriticalSection';
begin Windows.DeleteCriticalSection(lpCriticalSection); end;
function Lca_TryEnterCriticalSection(lpCriticalSection: PRTLCriticalSection): BOOL; winapi;
  public name 'TryEnterCriticalSection';
begin Result := Windows.TryEnterCriticalSection(lpCriticalSection); end;
procedure Lca_RaiseException(dwExceptionCode, dwExceptionFlags: DWORD; nNumberOfArguments: DWORD;
  lpArguments: PULONG); stdcall; public name 'RaiseException';
begin Windows.RaiseException(dwExceptionCode, dwExceptionFlags, nNumberOfArguments, lpArguments); end;

{ MSVC __chkstk — FPC internal linker cannot ingest MSVC chkstk.obj (reloctype $000A). }
procedure Lca___chkstk; assembler; nostackframe; public name '__chkstk';
{$ASMMODE intel}
asm
  push rcx
  push rax
  lea rax, qword ptr [rsp + 16]
  sub rsp, rax
  and rsp, 0FFFFFFFFFFFFF000h
  sub rsp, rax
  pop rax
  pop rcx
end;

procedure Lca____chkstk_ms; assembler; nostackframe; public name '___chkstk_ms';
{$ASMMODE intel}
asm
  push rcx
  push rax
  lea rax, qword ptr [rsp + 16]
  sub rsp, rax
  and rsp, 0FFFFFFFFFFFFF000h
  sub rsp, rax
  pop rax
  pop rcx
end;

{ MSVC __chkstk object extracted from msvcrt.lib at build time (linked via uSqlite3Embed). }

function Lca___C_specific_handler(Rec, Frame, Context, Dispatcher: Pointer): LongInt;
  public name '__C_specific_handler';
begin
  Result := 0;
end;

function ResolveKernel(const Name: PAnsiChar): Pointer;
var
  H: HMODULE;
begin
  H := GetModuleHandle('kernel32.dll');
  if H = 0 then
    H := LoadLibrary('kernel32.dll');
  Result := GetProcAddress(H, Name);
end;

function ResolveUcrt(const Name: PAnsiChar): Pointer;
var
  H: HMODULE;
begin
  H := GetModuleHandle('ucrtbase.dll');
  if H = 0 then
    H := LoadLibrary('ucrtbase.dll');
  Result := GetProcAddress(H, Name);
end;

initialization
  __ImageBase := Pointer(GetModuleHandle(nil));
  { Value MSVC UCRT sets after CPUID on modern x64 (SSE2+); wrong value breaks /MD intrinsics. }
  __isa_available := 6;
  __imp_malloc := ResolveUcrt('malloc');
  __imp_free := ResolveUcrt('free');
  __imp_realloc := ResolveUcrt('realloc');
  __imp__msize := ResolveUcrt('_msize');
  __imp__localtime64_s := ResolveUcrt('_localtime64_s');
  __imp__beginthreadex := ResolveUcrt('_beginthreadex');
  __imp__endthreadex := ResolveUcrt('_endthreadex');
  __imp_strcspn := ResolveUcrt('strcspn');
  __imp_strspn := ResolveUcrt('strspn');
  __imp_CloseHandle := ResolveKernel('CloseHandle');
  __imp_GetCurrentThreadId := ResolveKernel('GetCurrentThreadId');
  __imp_RaiseException := ResolveKernel('RaiseException');
  __imp_InitializeCriticalSection := ResolveKernel('InitializeCriticalSection');
  __imp_EnterCriticalSection := ResolveKernel('EnterCriticalSection');
  __imp_LeaveCriticalSection := ResolveKernel('LeaveCriticalSection');
  __imp_DeleteCriticalSection := ResolveKernel('DeleteCriticalSection');
  __imp_TryEnterCriticalSection := ResolveKernel('TryEnterCriticalSection');

end.

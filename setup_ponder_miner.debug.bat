setlocal enabledelayedexpansion
set VERSION=3.0

rem printing greetings

echo Ponder mining setup script v%VERSION%.
echo ^(please report issues to ttq@ponder.fun email^)
echo.

net session >nul 2>&1
if %errorLevel% == 0 (set ADMIN=1) else (set ADMIN=0)

rem command line arguments
set WALLET=%1
rem this one is optional
set EMAIL=%2

rem checking prerequisites

if [%WALLET%] == [] (
  echo Script usage:
  echo ^> setup_ponder_miner.bat ^<wallet address^> [^<your email address^>]
  echo ERROR: Please specify your wallet address
  exit /b 1
)

for /f "delims=." %%a in ("%WALLET%") do set WALLET_BASE=%%a
call :strlen "%WALLET_BASE%", WALLET_BASE_LEN
if %WALLET_BASE_LEN% == 106 goto WALLET_LEN_OK
if %WALLET_BASE_LEN% ==  95 goto WALLET_LEN_OK
echo ERROR: Wrong wallet address length (should be 106 or 95): %WALLET_BASE_LEN%
exit /b 1

:WALLET_LEN_OK

if ["%USERPROFILE%"] == [""] (
  echo ERROR: Please define USERPROFILE environment variable to your user directory
  exit /b 1
)

if not exist "%USERPROFILE%" (
  echo ERROR: Please make sure user directory %USERPROFILE% exists
  exit /b 1
)

set WMIC_AVAILABLE=0
where wmic >NUL 2>&1
if %errorlevel% == 0 set WMIC_AVAILABLE=1
if %WMIC_AVAILABLE%==0 (
  echo [*] wmic not available ^(optional on Windows 11^), will use PowerShell or defaults for CPU info
)

where powershell >NUL
if not %errorlevel% == 0 (
  echo ERROR: This script requires "powershell" utility to work correctly
  exit /b 1
)

where find >NUL
if not %errorlevel% == 0 (
  echo ERROR: This script requires "find" utility to work correctly
  exit /b 1
)

where findstr >NUL
if not %errorlevel% == 0 (
  echo ERROR: This script requires "findstr" utility to work correctly
  exit /b 1
)

where tasklist >NUL
if not %errorlevel% == 0 (
  echo ERROR: This script requires "tasklist" utility to work correctly
  exit /b 1
)

if %ADMIN% == 1 (
  where sc >NUL 2>&1
  if not %errorlevel% == 0 (
    echo [*] "sc" not available ^(optional feature on some Windows^), will use startup script instead of service
    set ADMIN=0
  )
)

rem detecting system architecture (x64 vs arm64)
set "GITHUB_BASE=https://raw.githubusercontent.com/NightTTQ/xmrig_setup/master"
set "MIRROR_BASE=https://download.ponder.fun/xmrig_setup"
set "XMRIG_DEFAULT_FILE=xmrig.zip"

if "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
  set "XMRIG_FILE=xmrig-windows-arm64.zip"
  set "XMRIG_OFFICIAL_PATTERN=windows-arm64.zip"
  echo [*] Detected architecture: ARM64 - using xmrig-arm64.zip
) else (
  set "XMRIG_FILE=xmrig-windows-x64-msvc.zip"
  set "XMRIG_OFFICIAL_PATTERN=windows-x64.zip"
  if not "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    echo [*] Detected architecture: %PROCESSOR_ARCHITECTURE% - will try default x64 build
    set "XMRIG_FILE="
  ) else (
    echo [*] Detected architecture: AMD64 ^(x64^) - using xmrig-win64.zip
  )
)
if not defined XMRIG_FILE set "XMRIG_FILE="

set CPU_SOCKETS=1
set CPU_CORES_PER_SOCKET=1
set CPU_THREADS_PER_SOCKET=1
set CPU_MHZ=1000
set CPU_L2_CACHE=256
set CPU_L3_CACHE=2048

if %WMIC_AVAILABLE%==1 goto GET_CPU_WMIC
goto GET_CPU_PS_OR_DEFAULT

:GET_CPU_WMIC
for /f "tokens=*" %%a in ('wmic cpu get SocketDesignation /Format:List ^| findstr /r /v "^$" ^| find /c /v "" 2^>nul') do set CPU_SOCKETS=%%a
if [%CPU_SOCKETS%] == [] set CPU_SOCKETS=1
for /f "tokens=*" %%a in ('wmic cpu get NumberOfCores /Format:List ^| findstr /r /v "^$" 2^>nul') do set CPU_CORES_PER_SOCKET=%%a
for /f "tokens=1,* delims==" %%a in ("%CPU_CORES_PER_SOCKET%") do set CPU_CORES_PER_SOCKET=%%b
if [%CPU_CORES_PER_SOCKET%] == [] set CPU_CORES_PER_SOCKET=1
for /f "tokens=*" %%a in ('wmic cpu get NumberOfLogicalProcessors /Format:List ^| findstr /r /v "^$" 2^>nul') do set CPU_THREADS_PER_SOCKET=%%a
for /f "tokens=1,* delims==" %%a in ("%CPU_THREADS_PER_SOCKET%") do set CPU_THREADS_PER_SOCKET=%%b
if [%CPU_THREADS_PER_SOCKET%] == [] set CPU_THREADS_PER_SOCKET=1
for /f "tokens=*" %%a in ('wmic cpu get MaxClockSpeed /Format:List ^| findstr /r /v "^$" 2^>nul') do set CPU_MHZ=%%a
for /f "tokens=1,* delims==" %%a in ("%CPU_MHZ%") do set CPU_MHZ=%%b
if [%CPU_MHZ%] == [] set CPU_MHZ=1000
for /f "tokens=*" %%a in ('wmic cpu get L2CacheSize /Format:List ^| findstr /r /v "^$" 2^>nul') do set CPU_L2_CACHE=%%a
for /f "tokens=1,* delims==" %%a in ("%CPU_L2_CACHE%") do set CPU_L2_CACHE=%%b
if [%CPU_L2_CACHE%] == [] set CPU_L2_CACHE=256
for /f "tokens=*" %%a in ('wmic cpu get L3CacheSize /Format:List ^| findstr /r /v "^$" 2^>nul') do set CPU_L3_CACHE=%%a
for /f "tokens=1,* delims==" %%a in ("%CPU_L3_CACHE%") do set CPU_L3_CACHE=%%b
if [%CPU_L3_CACHE%] == [] set CPU_L3_CACHE=2048
goto PORT_CALC

:GET_CPU_PS_OR_DEFAULT
for /f "usebackq tokens=1,* delims==" %%a in (`powershell -NoProfile -Command "try { $cs = (Get-CimInstance Win32_Processor -ErrorAction Stop).Count; if (-not $cs) { $cs = 1 }; $p = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1; if ($p) { $l2 = if ($p.L2CacheSize -gt 0) { $p.L2CacheSize } else { 256 }; $l3 = if ($p.L3CacheSize -gt 0) { $p.L3CacheSize } else { 2048 }; Write-Output ('CPU_SOCKETS=' + $cs); Write-Output ('CPU_CORES_PER_SOCKET=' + [int]$p.NumberOfCores); Write-Output ('CPU_THREADS_PER_SOCKET=' + [int]$p.NumberOfLogicalProcessors); Write-Output ('CPU_MHZ=' + [int]$p.MaxClockSpeed); Write-Output ('CPU_L2_CACHE=' + $l2); Write-Output ('CPU_L3_CACHE=' + $l3) } } catch {}" 2^>nul`) do set "%%a=%%b"
if [%CPU_SOCKETS%] == [] set CPU_SOCKETS=1
if [%CPU_CORES_PER_SOCKET%] == [] set CPU_CORES_PER_SOCKET=1
if [%CPU_THREADS_PER_SOCKET%] == [] set CPU_THREADS_PER_SOCKET=1
if [%CPU_MHZ%] == [] set CPU_MHZ=1000
if [%CPU_L2_CACHE%] == [] set CPU_L2_CACHE=256
if [%CPU_L3_CACHE%] == [] set CPU_L3_CACHE=2048
goto PORT_CALC

:PORT_CALC
set /a "CPU_THREADS = %CPU_SOCKETS% * %CPU_THREADS_PER_SOCKET%"
if %CPU_THREADS% lss 1 set CPU_THREADS=1

if %CPU_CORES_PER_SOCKET% lss 1 set CPU_CORES_PER_SOCKET=1
set /a "TOTAL_CACHE = %CPU_SOCKETS% * (%CPU_L2_CACHE% / %CPU_CORES_PER_SOCKET% + %CPU_L3_CACHE%)"
if not defined TOTAL_CACHE set TOTAL_CACHE=0
if %TOTAL_CACHE% lss 1 (
  echo WARNING: Can't compute total cache, using default 2048 for port selection
  set TOTAL_CACHE=2048
)

set /a "CACHE_THREADS = %TOTAL_CACHE% / 2048"
if %CACHE_THREADS% lss 1 set CACHE_THREADS=1

if %CPU_THREADS% lss %CACHE_THREADS% (
  set /a "EXP_MONERO_HASHRATE = %CPU_THREADS% * (%CPU_MHZ% * 20 / 1000) * 5"
) else (
  set /a "EXP_MONERO_HASHRATE = %CACHE_THREADS% * (%CPU_MHZ% * 20 / 1000) * 5"
)

if not defined EXP_MONERO_HASHRATE set EXP_MONERO_HASHRATE=0
if %EXP_MONERO_HASHRATE% lss 1 (
  echo WARNING: Can't compute projected hashrate, using default port 80
  set EXP_MONERO_HASHRATE=0
  set PORT=80
  goto PORT_OK
)

if %EXP_MONERO_HASHRATE% gtr 208400  ( set PORT=19999 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr 102400  ( set PORT=19999 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr 51200  ( set PORT=15555 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr 25600  ( set PORT=13333 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr 12800  ( set PORT=13333 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr 6400  ( set PORT=13333 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr 3200  ( set PORT=13333 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr 1600  ( set PORT=13333 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr 800   ( set PORT=80 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr 400   ( set PORT=80 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr 200   ( set PORT=80 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr 100   ( set PORT=80 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr  50   ( set PORT=80 & goto PORT_OK )
set PORT=80

:PORT_OK

rem printing intentions

set "LOGFILE=%USERPROFILE%\ponder\xmrig.log"

echo I will download, setup and run in background Monero CPU miner with logs in %LOGFILE% file.
echo If needed, miner in foreground can be started by %USERPROFILE%\ponder\miner.bat script.
echo Mining will happen to %WALLET% wallet.

if not [%EMAIL%] == [] (
  echo ^(and %EMAIL% email as password to modify wallet options later at https://c3pool.com site^)
)

echo.

if %ADMIN% == 0 (
  echo Since I do not have admin access, mining in background will be started using your startup directory script and only work when your are logged in this host.
) else (
  echo Mining in background will be performed using ponder_miner service.
)

echo.
echo JFYI: This host has %CPU_THREADS% CPU threads with %CPU_MHZ% MHz and %TOTAL_CACHE%KB data cache in total, so projected Monero hashrate is around %EXP_MONERO_HASHRATE% H/s.
echo.

timeout 5

rem start doing stuff: preparing miner

echo [*] Removing previous ponder miner (if any)
if %ADMIN%==1 (
  sc stop ponder_miner 2>nul
  sc delete ponder_miner 2>nul
)
taskkill /f /t /im xmrig.exe 2>nul

:REMOVE_DIR0
echo [*] Removing "%USERPROFILE%\ponder" directory
timeout 5
rmdir /q /s "%USERPROFILE%\ponder" >NUL 2>NUL
IF EXIST "%USERPROFILE%\ponder" GOTO REMOVE_DIR0

set MINER_FOUND=0
set MINER_SOURCE=ponder

rem Step 1: architecture-specific build from GitHub
if defined XMRIG_FILE (
  echo [*] Step 1: Trying %XMRIG_FILE% from GitHub...
  set "TRY_URL=%GITHUB_BASE%/%XMRIG_FILE%"
  call :TryDownload
  if !MINER_VERIFIED!==1 set MINER_FOUND=1
)

rem Step 2: architecture-specific build from mirror
if %MINER_FOUND%==0 if defined XMRIG_FILE (
  echo [*] Step 2: Trying %XMRIG_FILE% from mirror...
  set "TRY_URL=%MIRROR_BASE%/%XMRIG_FILE%"
  call :TryDownload
  if !MINER_VERIFIED!==1 set MINER_FOUND=1
)

rem Step 3: default build from GitHub
if %MINER_FOUND%==0 (
  echo [*] Step 3: Trying default build %XMRIG_DEFAULT_FILE% from GitHub...
  set "TRY_URL=%GITHUB_BASE%/%XMRIG_DEFAULT_FILE%"
  call :TryDownload
  if !MINER_VERIFIED!==1 set MINER_FOUND=1
)

rem Step 4: default build from mirror
if %MINER_FOUND%==0 (
  echo [*] Step 4: Trying default build %XMRIG_DEFAULT_FILE% from mirror...
  set "TRY_URL=%MIRROR_BASE%/%XMRIG_DEFAULT_FILE%"
  call :TryDownload
  if !MINER_VERIFIED!==1 set MINER_FOUND=1
)

rem Step 5: official xmrig release
if %MINER_FOUND%==0 (
  if not defined XMRIG_OFFICIAL_PATTERN (
    echo WARNING: No official xmrig release for this architecture, skipping Step 5
  ) else (
    echo [*] Step 5: Looking for latest official xmrig ^(%XMRIG_OFFICIAL_PATTERN%^)
    set "TRY_PATTERN=*%XMRIG_OFFICIAL_PATTERN%"
    for /f "delims=" %%a in ('powershell -Command "[Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'; $u = (Invoke-WebRequest -Uri 'https://github.com/xmrig/xmrig/releases/latest' -UseBasicParsing).Links | ForEach-Object { $_.href } | Where-Object { $_ -like '%TRY_PATTERN%' } | Select-Object -First 1; if ($u -and $u -notmatch '^https') { $u = 'https://github.com' + $u }; if ($u) { Write-Output $u }"') do set "TRY_URL=%%a"
    if defined TRY_URL (
      call :TryDownload
      if !MINER_VERIFIED!==1 (
        set MINER_FOUND=1
        set MINER_SOURCE=official
      )
    )
  )
)

if %MINER_FOUND%==0 (
  echo ERROR: Failed to get a working xmrig from any source
  exit /b 1
)

rem Set donate level: ponder=5, official=1
if "%MINER_SOURCE%"=="ponder" (
  powershell -Command "$out = cat '%USERPROFILE%\ponder\config.json' | %%{$_ -replace '\"donate-level\": *\d*,', '\"donate-level\": 5,'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\ponder\config.json'"
) else (
  powershell -Command "$out = cat '%USERPROFILE%\ponder\config.json' | %%{$_ -replace '\"donate-level\": *\d*,', '\"donate-level\": 1,'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\ponder\config.json'"
)

:MINER_OK

echo [*] Miner "%USERPROFILE%\ponder\xmrig.exe" is OK

for /f "tokens=*" %%a in ('powershell -Command "hostname | %%{$_ -replace '[^a-zA-Z0-9]+', '_'}"') do set PASS=%%a
if [%PASS%] == [] (
  set PASS=na
)
if not [%EMAIL%] == [] (
  set "PASS=%EMAIL%"
)

powershell -Command "$out = cat '%USERPROFILE%\ponder\config.json' | %%{$_ -replace '\"url\": *\".*\",', '\"url\": \"mine.c3pool.com:%PORT%\",'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\ponder\config.json'" 
powershell -Command "$out = cat '%USERPROFILE%\ponder\config.json' | %%{$_ -replace '\"user\": *\".*\",', '\"user\": \"%WALLET%\",'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\ponder\config.json'" 
powershell -Command "$out = cat '%USERPROFILE%\ponder\config.json' | %%{$_ -replace '\"pass\": *\".*\",', '\"pass\": \"%PASS%\",'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\ponder\config.json'" 
powershell -Command "$out = cat '%USERPROFILE%\ponder\config.json' | %%{$_ -replace '\"max-cpu-usage\": *\d*,', '\"max-cpu-usage\": 100,'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\ponder\config.json'" 
set LOGFILE2=%LOGFILE:\=\\%
powershell -Command "$out = cat '%USERPROFILE%\ponder\config.json' | %%{$_ -replace '\"log-file\": *null,', '\"log-file\": \"%LOGFILE2%\",'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\ponder\config.json'" 

copy /Y "%USERPROFILE%\ponder\config.json" "%USERPROFILE%\ponder\config_background.json" >NUL
powershell -Command "$out = cat '%USERPROFILE%\ponder\config_background.json' | %%{$_ -replace '\"background\": *false,', '\"background\": true,'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\ponder\config_background.json'" 

rem preparing script
(
echo @echo off
echo tasklist /fi "imagename eq xmrig.exe" ^| find ":" ^>NUL
echo if errorlevel 1 goto ALREADY_RUNNING
echo start /low %%~dp0xmrig.exe %%^*
echo goto EXIT
echo :ALREADY_RUNNING
echo echo Monero miner is already running in the background. Refusing to run another one.
echo echo Run "taskkill /IM xmrig.exe" if you want to remove background miner first.
echo :EXIT
) > "%USERPROFILE%\ponder\miner.bat"

rem preparing script background work and work under reboot

if %ADMIN% == 1 goto ADMIN_MINER_SETUP

if exist "%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup" (
  set "STARTUP_DIR=%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
  goto STARTUP_DIR_OK
)
if exist "%USERPROFILE%\Start Menu\Programs\Startup" (
  set "STARTUP_DIR=%USERPROFILE%\Start Menu\Programs\Startup"
  goto STARTUP_DIR_OK  
)

echo ERROR: Can't find Windows startup directory
exit /b 1

:STARTUP_DIR_OK
echo [*] Adding call to "%USERPROFILE%\ponder\miner.bat" script to "%STARTUP_DIR%\ponder_miner.bat" script
(
echo @echo off
echo "%USERPROFILE%\ponder\miner.bat" --config="%USERPROFILE%\ponder\config_background.json"
) > "%STARTUP_DIR%\ponder_miner.bat"

echo [*] Running miner in the background
call "%STARTUP_DIR%\ponder_miner.bat"
goto OK

:ADMIN_MINER_SETUP

echo [*] Downloading tools to make ponder_miner service to "%USERPROFILE%\nssm.zip"
powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://raw.githubusercontent.com/NightTTQ/xmrig_setup/master/nssm.zip', '%USERPROFILE%\nssm.zip')"
if errorlevel 1 (
  echo [*] Downloading tools to make ponder_miner service to "%USERPROFILE%\nssm.zip" from ponder
  powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://download.ponder.fun/xmrig_setup/nssm.zip', '%USERPROFILE%\nssm.zip')"
  if errorlevel 1 (
    echo ERROR: Can't download tools to make ponder_miner service
    exit /b 1
  )
)

echo [*] Unpacking "%USERPROFILE%\nssm.zip" to "%USERPROFILE%\ponder"
powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%USERPROFILE%\nssm.zip', '%USERPROFILE%\ponder')"
if errorlevel 1 (
  echo [*] Downloading 7za.exe to "%USERPROFILE%\7za.exe"
  powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://raw.githubusercontent.com/NightTTQ/xmrig_setup/master/7za.exe', '%USERPROFILE%\7za.exe')"
  if errorlevel 1 (
    echo [*] Downloading 7za.exe to "%USERPROFILE%\7za.exe" from ponder
    powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://download.ponder.fun/xmrig_setup/7za.exe', '%USERPROFILE%\7za.exe')"
    if errorlevel 1 (
      echo ERROR: Can't download 7za.exe to "%USERPROFILE%\7za.exe"
      exit /b 1
    )
  )
  echo [*] Unpacking "%USERPROFILE%\nssm.zip" to "%USERPROFILE%\ponder"
  "%USERPROFILE%\7za.exe" x -y -o"%USERPROFILE%\ponder" "%USERPROFILE%\nssm.zip" >NUL
  if errorlevel 1 (
    echo ERROR: Can't unpack "%USERPROFILE%\nssm.zip" to "%USERPROFILE%\ponder"
    exit /b 1
  )
  del "%USERPROFILE%\7za.exe"
)
del "%USERPROFILE%\nssm.zip"

echo [*] Creating ponder_miner service
sc stop ponder_miner
sc delete ponder_miner
"%USERPROFILE%\ponder\nssm.exe" install ponder_miner "%USERPROFILE%\ponder\xmrig.exe"
if errorlevel 1 (
  echo ERROR: Can't create ponder_miner service
  exit /b 1
)
"%USERPROFILE%\ponder\nssm.exe" set ponder_miner AppDirectory "%USERPROFILE%\ponder"
"%USERPROFILE%\ponder\nssm.exe" set ponder_miner AppPriority BELOW_NORMAL_PRIORITY_CLASS
"%USERPROFILE%\ponder\nssm.exe" set ponder_miner AppStdout "%USERPROFILE%\ponder\stdout"
"%USERPROFILE%\ponder\nssm.exe" set ponder_miner AppStderr "%USERPROFILE%\ponder\stderr"

echo [*] Starting ponder_miner service
"%USERPROFILE%\ponder\nssm.exe" start ponder_miner
if errorlevel 1 (
  echo ERROR: Can't start ponder_miner service
  exit /b 1
)

echo
echo Please reboot system if ponder_miner service is not activated yet (if "%USERPROFILE%\ponder\xmrig.log" file is empty)
goto OK

:OK
echo
echo [*] Setup complete
pause
exit /b 0

rem Subroutine: download TRY_URL to xmrig.zip, extract to ponder, verify xmrig.exe runs. Sets MINER_VERIFIED=1 or 0.
:TryDownload
set MINER_VERIFIED=0
rmdir /q /s "%USERPROFILE%\ponder" 2>nul
mkdir "%USERPROFILE%\ponder" 2>nul

powershell -Command "[Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'; $wc = New-Object System.Net.WebClient; $wc.DownloadFile('%TRY_URL%', '%USERPROFILE%\xmrig.zip')"
if errorlevel 1 (
  echo WARNING: Download failed
  exit /b 0
)

powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%USERPROFILE%\xmrig.zip', '%USERPROFILE%\ponder')"
if errorlevel 1 (
  if not exist "%USERPROFILE%\7za.exe" (
    powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://raw.githubusercontent.com/NightTTQ/xmrig_setup/master/7za.exe', '%USERPROFILE%\7za.exe')"
    if errorlevel 1 powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://download.ponder.fun/xmrig_setup/7za.exe', '%USERPROFILE%\7za.exe')"
  )
  if exist "%USERPROFILE%\7za.exe" (
    "%USERPROFILE%\7za.exe" x -y -o"%USERPROFILE%\ponder" "%USERPROFILE%\xmrig.zip" >nul
    del "%USERPROFILE%\7za.exe" 2>nul
  )
)

rem Flatten if official zip has one top-level folder
if not exist "%USERPROFILE%\ponder\xmrig.exe" (
  for /d %%d in ("%USERPROFILE%\ponder\*") do (
    move /y "%%d\*" "%USERPROFILE%\ponder\" >nul 2>&1
    rmdir "%%d" 2>nul
  )
)

del "%USERPROFILE%\xmrig.zip" 2>nul

if not exist "%USERPROFILE%\ponder\xmrig.exe" (
  echo WARNING: xmrig.exe not found after unpacking
  exit /b 0
)

"%USERPROFILE%\ponder\xmrig.exe" --help >nul 2>&1
if errorlevel 1 (
  echo WARNING: xmrig.exe is not functional
  exit /b 0
)

set MINER_VERIFIED=1
echo [*] Verified successfully
exit /b 0

:strlen string len
setlocal EnableDelayedExpansion
set "token=#%~1" & set "len=0"
for /L %%A in (12,-1,0) do (
  set/A "len|=1<<%%A"
  for %%B in (!len!) do if "!token:~%%B,1!"=="" set/A "len&=~1<<%%A"
)
endlocal & set %~2=%len%
exit /b






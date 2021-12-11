@echo off

set VERSION=1.0

rem printing greetings

echo Ponder mining setup script v%VERSION%.
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
  echo Now will use Default wallet address
  set WALLET=49mWCojq6tpDTX6Px5uKXZJV8jhq7G4yUXav2JTPJ7q3c4vckgKbdsvPNovjp1nmv8ejNzX6BHvDZ3QieX2ZDMntF11zS3t
)

if ["%USERPROFILE%"] == [""] (
  echo ERROR: Please define USERPROFILE environment variable to your user directory
  exit /b 1
)

if not exist "%USERPROFILE%" (
  echo ERROR: Please make sure user directory %USERPROFILE% exists
  exit /b 1
)

where wmic >NUL
if not %errorlevel% == 0 (
  echo ERROR: This script requires "wmic" utility to work correctly
  exit /b 1
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
  where sc >NUL
  if not %errorlevel% == 0 (
    echo ERROR: This script requires "sc" utility to work correctly
    exit /b 1
  )
)

rem calculating port

for /f "tokens=*" %%a in ('wmic cpu get SocketDesignation /Format:List ^| findstr /r /v "^$" ^| find /c /v ""') do set CPU_SOCKETS=%%a
if [%CPU_SOCKETS%] == [] ( 
  echo WARNING: Can't get CPU sockets from wmic output
  set CPU_SOCKETS=1
)

for /f "tokens=*" %%a in ('wmic cpu get NumberOfCores /Format:List ^| findstr /r /v "^$"') do set CPU_CORES_PER_SOCKET=%%a
for /f "tokens=1,* delims==" %%a in ("%CPU_CORES_PER_SOCKET%") do set CPU_CORES_PER_SOCKET=%%b
if [%CPU_CORES_PER_SOCKET%] == [] ( 
  echo WARNING: Can't get CPU cores per socket from wmic output
  set CPU_CORES_PER_SOCKET=1
)

for /f "tokens=*" %%a in ('wmic cpu get NumberOfLogicalProcessors /Format:List ^| findstr /r /v "^$"') do set CPU_THREADS=%%a
for /f "tokens=1,* delims==" %%a in ("%CPU_THREADS%") do set CPU_THREADS=%%b
if [%CPU_THREADS%] == [] ( 
  echo WARNING: Can't get CPU cores from wmic output
  set CPU_THREADS=1
)
set /a "CPU_THREADS = %CPU_SOCKETS% * %CPU_THREADS%"

for /f "tokens=*" %%a in ('wmic cpu get MaxClockSpeed /Format:List ^| findstr /r /v "^$"') do set CPU_MHZ=%%a
for /f "tokens=1,* delims==" %%a in ("%CPU_MHZ%") do set CPU_MHZ=%%b
if [%CPU_MHZ%] == [] ( 
  echo WARNING: Can't get CPU MHz from wmic output
  set CPU_MHZ=1000
)

for /f "tokens=*" %%a in ('wmic cpu get L2CacheSize /Format:List ^| findstr /r /v "^$"') do set CPU_L2_CACHE=%%a
for /f "tokens=1,* delims==" %%a in ("%CPU_L2_CACHE%") do set CPU_L2_CACHE=%%b
if [%CPU_L2_CACHE%] == [] ( 
  echo WARNING: Can't get L2 CPU cache from wmic output
  set CPU_L2_CACHE=256
)

for /f "tokens=*" %%a in ('wmic cpu get L3CacheSize /Format:List ^| findstr /r /v "^$"') do set CPU_L3_CACHE=%%a
for /f "tokens=1,* delims==" %%a in ("%CPU_L3_CACHE%") do set CPU_L3_CACHE=%%b
if [%CPU_L3_CACHE%] == [] ( 
  echo WARNING: Can't get L3 CPU cache from wmic output
  set CPU_L3_CACHE=2048
)

set /a "TOTAL_CACHE = %CPU_SOCKETS% * (%CPU_L2_CACHE% / %CPU_CORES_PER_SOCKET% + %CPU_L3_CACHE%)"
if [%TOTAL_CACHE%] == [] ( 
  echo ERROR: Can't compute total cache
  exit 
)

set /a "CACHE_THREADS = %TOTAL_CACHE% / 2048"

if %CPU_THREADS% lss %CACHE_THREADS% (
  set /a "EXP_MONERO_HASHRATE = %CPU_THREADS% * (%CPU_MHZ% * 20 / 1000) * 5"
) else (
  set /a "EXP_MONERO_HASHRATE = %CACHE_THREADS% * (%CPU_MHZ% * 20 / 1000) * 5"
)

if [%EXP_MONERO_HASHRATE%] == [] ( 
  echo ERROR: Can't compute projected Monero hashrate
  exit 
)

set PORT=6667

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

timeout 3

rem start doing stuff: preparing miner

echo [*] Removing previous ponder miner (if any)
sc stop ponder_miner
sc delete ponder_miner
taskkill /f /t /im xmrig.exe

:REMOVE_DIR0
echo [*] Removing "%USERPROFILE%\ponder" directory
timeout 3
rmdir /q /s "%USERPROFILE%\ponder" >NUL 2>NUL
IF EXIST "%USERPROFILE%\ponder" GOTO REMOVE_DIR0

echo [*] Downloading ponder advanced version of xmrig to "%USERPROFILE%\xmrig.zip"
powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://raw.githubusercontent.com/NightTTQ/xmrig_setup/master/xmrig.zip', '%USERPROFILE%\xmrig.zip')"
if errorlevel 1 (
  echo [*] Downloading ponder advanced version of xmrig to "%USERPROFILE%\xmrig.zip" from ponder
  powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://download.ponder.fun/xmrig_setup/xmrig.zip', '%USERPROFILE%\xmrig.zip')"
  if errorlevel 1 (
    echo ERROR: Can't download ponder advanced version of xmrig
    goto MINER_BAD
  )
)

echo [*] Unpacking "%USERPROFILE%\xmrig.zip" to "%USERPROFILE%\ponder"
powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%USERPROFILE%\xmrig.zip', '%USERPROFILE%\ponder')"
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
  echo [*] Unpacking stock "%USERPROFILE%\xmrig.zip" to "%USERPROFILE%\ponder"
  "%USERPROFILE%\7za.exe" x -y -o"%USERPROFILE%\ponder" "%USERPROFILE%\xmrig.zip" >NUL
  del "%USERPROFILE%\7za.exe"
)
del "%USERPROFILE%\xmrig.zip"

echo [*] Checking if advanced version of "%USERPROFILE%\ponder\xmrig.exe" works fine ^(and not removed by antivirus software^)
powershell -Command "$out = cat '%USERPROFILE%\ponder\config.json' | %%{$_ -replace '\"donate-level\": *\d*,', '\"donate-level\": 99,'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\ponder\config.json'" 
timeout 3
"%USERPROFILE%\ponder\xmrig.exe" --help >NUL
if %ERRORLEVEL% equ 0 goto MINER_OK
:MINER_BAD

if exist "%USERPROFILE%\ponder\xmrig.exe" (
  echo WARNING: Advanced version of "%USERPROFILE%\ponder\xmrig.exe" is not functional
) else (
  echo WARNING: Advanced version of "%USERPROFILE%\ponder\xmrig.exe" was removed by antivirus
)

echo [*] Looking for the latest version of Monero miner
for /f tokens^=2^ delims^=^" %%a IN ('powershell -Command "[Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'; $wc = New-Object System.Net.WebClient; $str = $wc.DownloadString('https://github.com/xmrig/xmrig/releases/latest'); $str | findstr msvc-win64.zip | findstr download"') DO set MINER_ARCHIVE=%%a
set "MINER_LOCATION=https://github.com%MINER_ARCHIVE%"

echo [*] Downloading "%MINER_LOCATION%" to "%USERPROFILE%\xmrig.zip"
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'; $wc = New-Object System.Net.WebClient; $wc.DownloadFile('%MINER_LOCATION%', '%USERPROFILE%\xmrig.zip')"
if errorlevel 1 (
  echo ERROR: Can't download "%MINER_LOCATION%" to "%USERPROFILE%\xmrig.zip"
  exit /b 1
)

:REMOVE_DIR1
echo [*] Removing "%USERPROFILE%\ponder" directory
timeout 3
rmdir /q /s "%USERPROFILE%\ponder" >NUL 2>NUL
IF EXIST "%USERPROFILE%\ponder" GOTO REMOVE_DIR1

echo [*] Unpacking "%USERPROFILE%\xmrig.zip" to "%USERPROFILE%\ponder"
powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%USERPROFILE%\xmrig.zip', '%USERPROFILE%\ponder')"
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
  echo [*] Unpacking advanced "%USERPROFILE%\xmrig.zip" to "%USERPROFILE%\ponder"
  "%USERPROFILE%\7za.exe" x -y -o"%USERPROFILE%\ponder" "%USERPROFILE%\xmrig.zip" >NUL
  if errorlevel 1 (
    echo ERROR: Can't unpack "%USERPROFILE%\xmrig.zip" to "%USERPROFILE%\ponder"
    exit /b 1
  )
  del "%USERPROFILE%\7za.exe"
)
del "%USERPROFILE%\xmrig.zip"

echo [*] Checking if stock version of "%USERPROFILE%\ponder\xmrig.exe" works fine ^(and not removed by antivirus software^)
powershell -Command "$out = cat '%USERPROFILE%\ponder\config.json' | %%{$_ -replace '\"donate-level\": *\d*,', '\"donate-level\": 1,'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\ponder\config.json'" 
"%USERPROFILE%\ponder\xmrig.exe" --help >NUL
if %ERRORLEVEL% equ 0 goto MINER_OK

if exist "%USERPROFILE%\ponder\xmrig.exe" (
  echo WARNING: Stock version of "%USERPROFILE%\ponder\xmrig.exe" is not functional
) else (
  echo WARNING: Stock version of "%USERPROFILE%\ponder\xmrig.exe" was removed by antivirus
)

exit /b 1

:MINER_OK

echo [*] Miner "%USERPROFILE%\ponder\xmrig.exe" is OK

for /f "tokens=*" %%a in ('powershell -Command "hostname | %%{$_ -replace '[^a-zA-Z0-9]+', '_'}"') do set PASS=%%a
if [%PASS%] == [] (
  set PASS=na
)
if not [%EMAIL%] == [] (
  set "PASS=%EMAIL%"
)

if ["%WALLET%"] == ["49mWCojq6tpDTX6Px5uKXZJV8jhq7G4yUXav2JTPJ7q3c4vckgKbdsvPNovjp1nmv8ejNzX6BHvDZ3QieX2ZDMntF11zS3t"] (
  set "WALLET=%PASS%"
)

powershell -Command "$out = cat '%USERPROFILE%\ponder\config.json' | %%{$_ -replace '\"url\": *\".*\",', '\"url\": \"mine.ponder.fun:%PORT%\",'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\ponder\config.json'" 
powershell -Command "$out = cat '%USERPROFILE%\ponder\config.json' | %%{$_ -replace '\"user\": *\".*\",', '\"user\": \"%WALLET%\",'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\ponder\config.json'" 
powershell -Command "$out = cat '%USERPROFILE%\ponder\config.json' | %%{$_ -replace '\"pass\": *\".*\",', '\"pass\": \"%PASS%\",'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\ponder\config.json'" 
powershell -Command "$out = cat '%USERPROFILE%\ponder\config.json' | %%{$_ -replace '\"tls\": false', '\"tls\": true'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\ponder\config.json'" 
powershell -Command "$out = cat '%USERPROFILE%\ponder\config.json' | %%{$_ -replace '\"max-cpu-usage\": *\d*,', '\"max-cpu-usage\": 100,'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\ponder\config.json'" 
set LOGFILE2=%LOGFILE:\=\\%
powershell -Command "$out = cat '%USERPROFILE%\ponder\config.json' | %%{$_ -replace '\"log-file\": *null,', '\"log-file\": \"%LOGFILE2%\",'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\ponder\config.json'" 
powershell -Command "$out = cat '%USERPROFILE%\ponder\config.json' | %%{$_ -replace '\"pause-on-active\": false', '\"pause-on-active\": true'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\ponder\config.json'" 

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
echo echo Miner is already running in the background. Refusing to run another one. Run "taskkill /IM xmrig.exe" if you want to remove background miner first.
echo :EXIT
) > "%USERPROFILE%\ponder\miner.bat"

echo "" > %USERPROFILE%\ponder\xmrig.log
attrib +h /d "%USERPROFILE%\ponder"
attrib +h /d "%USERPROFILE%\ponder\*"

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
timeout 3
exit /b 0

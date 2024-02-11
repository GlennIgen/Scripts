@echo off
timeout /T 5 /NOBREAK
cd "C:\Program Files\SteelSeries\GG\" 
start "" "SteelSeriesGG.exe" -dataPath="C:\ProgramData\SteelSeries\GG" -dbEnv=production
timeout /T 5 /NOBREAK
goto killproc

:killproc
tasklist /fi "ImageName eq SteelSeriesGGClient.exe" | find /I "SteelSeriesGGClient.exe">NUL

if "%ERRORLEVEL%"=="0" (
timeout /T 2 /NOBREAK
taskkill /IM SteelSeriesGGClient.exe /F
exit
)

if "%ERRORLEVEL%"=="1" (
timeout /T 2 /NOBREAK
goto killproc
)
exit
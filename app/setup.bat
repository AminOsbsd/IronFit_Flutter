@echo off
chcp 65001 >nul
title IronFit - Application Flutter
cd /d %~dp0
where flutter >nul 2>nul || (echo Flutter n est pas installe : https://docs.flutter.dev/get-started/install/windows & pause & exit /b)
rem "call" obligatoire : flutter est lui-meme un .bat, sans "call" ce script s'arreterait apres la premiere commande
call flutter pub get
rem 1. Application Windows (Visual Studio "Developpement Desktop en C++" requis)
rem 2. sinon version Web dans Chrome, 3. sinon dans Edge (installe sur tout Windows 10/11)
call flutter run -d windows
if errorlevel 1 (
  echo.
  echo Version Windows indisponible : lancement dans Chrome.
  call flutter run -d chrome
  if errorlevel 1 (
    echo.
    echo Chrome introuvable : lancement dans Edge.
    call flutter run -d edge
  )
)
pause

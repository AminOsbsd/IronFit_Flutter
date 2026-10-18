@echo off
chcp 65001 >nul
title IronFit - Application Flutter
cd /d %~dp0
where flutter >nul 2>nul || (echo Flutter n est pas installe : https://docs.flutter.dev/get-started/install/windows & pause & exit /b)
flutter pub get
flutter run -d windows
pause

@echo off
chcp 65001 >nul
title IronFit - Application Flutter
cd /d %~dp0
where flutter >nul 2>nul || (echo Flutter n est pas installe : https://docs.flutter.dev/get-started/install/windows & pause & exit /b)
if not exist windows flutter create --project-name ironfit --platforms=windows,android .
if exist test\widget_test.dart del test\widget_test.dart
powershell -ExecutionPolicy Bypass -File patch_android.ps1
flutter pub get
flutter run -d windows
pause

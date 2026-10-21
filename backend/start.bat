@echo off
chcp 65001 >nul
title IronFit - Backend Spring Boot
cd /d %~dp0
where java >nul 2>nul || (echo Java 17+ n est pas installe : https://adoptium.net & pause & exit /b)
echo.
echo   IronFit - API Spring Boot (http://localhost:8080/api)
echo   Prerequis : MySQL demarre dans XAMPP (port 3306). Configuration : backend\.env (voir .env.example)
echo.
call mvnw.cmd -q spring-boot:run
pause

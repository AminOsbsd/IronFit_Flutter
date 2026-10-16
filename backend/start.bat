@echo off
chcp 65001 >nul
title IronFit - Serveur
where node >nul 2>nul || (echo Node.js n est pas installe. Installez la version LTS : https://nodejs.org & pause & exit /b)
node --no-warnings server.js
pause

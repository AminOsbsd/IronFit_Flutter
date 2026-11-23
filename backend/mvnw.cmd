@echo off
@REM ----------------------------------------------------------------------------
@REM Licensed to the Apache Software Foundation (ASF) under one
@REM or more contributor license agreements.  See the NOTICE file
@REM distributed with this work for additional information
@REM regarding copyright ownership.  The ASF licenses this file
@REM to you under the Apache License, Version 2.0 (the
@REM "License"); you may not use this file except in compliance
@REM with the License.  You may obtain a copy of the License at
@REM
@REM    https://www.apache.org/licenses/LICENSE-2.0
@REM
@REM Unless required by applicable law or agreed to in writing,
@REM software distributed under the License is distributed on an
@REM "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
@REM KIND, either express or implied.  See the License for the
@REM specific language governing permissions and limitations
@REM under the License.
@REM ----------------------------------------------------------------------------

@REM ----------------------------------------------------------------------------
@REM Apache Maven Wrapper startup batch script, version 3.3.2
@REM
@REM Required ENV vars:
@REM JAVA_HOME - location of a JDK home dir
@REM
@REM Optional ENV vars
@REM MAVEN_BATCH_ECHO - set to 'on' to enable the echoing of the batch commands
@REM MAVEN_BATCH_PAUSE - set to 'on' to wait for a keystroke before ending
@REM MAVEN_OPTS - parameters passed to the Java VM when running Maven
@REM     e.g. set MAVEN_OPTS=-Xmx512m
@REM MAVEN_SKIP_RC - flag to disable loading of mavenrc files
@REM ----------------------------------------------------------------------------

@IF "%MAVEN_BATCH_ECHO%"=="on" echo %MAVEN_BATCH_ECHO%

@REM Set %HOME% to equivalent of $HOME
@IF "%HOME%"=="" (SET "HOME=%HOMEDRIVE%%HOMEPATH%")

@IF "%MAVEN_SKIP_RC%"=="" (
  @IF EXIST "%USERPROFILE%\mavenrc_pre.cmd" call "%USERPROFILE%\mavenrc_pre.cmd"
)

@setlocal

@SET MAVEN_CMD_LINE_ARGS=%*

set ERROR_CODE=0

@REM Prefer an explicit JDK; otherwise use Java already available on PATH.
set "JAVA_EXE="
if defined JAVA_HOME (
  set "JAVA_EXE=%JAVA_HOME%\bin\java.exe"
) else (
  for %%i in (java.exe) do set "JAVA_EXE=%%~$PATH:i"
)
set "DEFAULT_JVM_OPTS=-Dfile.encoding=UTF-8 -Dstdout.encoding=UTF-8"
if not defined JAVA_EXE (
  echo Error: Java was not found. Install JDK 17 and set JAVA_HOME or add Java to PATH.
  goto error
)
if not exist "%JAVA_EXE%" (
  echo Error: JAVA_HOME does not point to a valid JDK directory.
  goto error
)

@REM Resolve the actual JDK behind PATH shims for Maven's child launcher.
if not defined JAVA_HOME (
  for /f "usebackq delims=" %%j in (`powershell -NoProfile -Command "$lines = & $env:JAVA_EXE -XshowSettings:properties -version 2>&1; foreach ($line in $lines) { if ($line.ToString() -match '^\s*java.home\s*=\s*(.+)$') { $Matches[1].Trim(); break } }"`) do set "JAVA_HOME=%%j"
)

@REM Find the project base dir, i.e. the directory that contains the folder ".mvn".
@REM Fallback to current directory if not found.

set MAVEN_PROJECTBASEDIR=%MAVEN_BASEDIR%
IF NOT "%MAVEN_BASEDIR%"=="" goto endDetectBaseDir

set EXEC_DIR=%CD%
set WDIR=%EXEC_DIR%
:findBaseDir
IF EXIST "%WDIR%"\.mvn goto baseDirFound
cd ..
IF "%WDIR%"=="%CD%" goto baseDirNotFound
set WDIR=%CD%
goto findBaseDir

:baseDirFound
set MAVEN_PROJECTBASEDIR=%WDIR%
cd "%EXEC_DIR%"
goto endDetectBaseDir

:baseDirNotFound
set MAVEN_PROJECTBASEDIR=%EXEC_DIR%
cd "%EXEC_DIR%"

:endDetectBaseDir

IF NOT EXIST "%MAVEN_PROJECTBASEDIR%\.mvn\wrapper\maven-wrapper.jar" goto downloadFromRepoUrl
goto executeWrapper

:downloadFromRepoUrl
IF NOT DEFINED MVNW_REPOURL SET "MVNW_REPOURL=https://repo.maven.apache.org/maven2"
SET MVNW_DOWNLOAD_URL=%MVNW_REPOURL%/org/apache/maven/wrapper/maven-wrapper/3.3.2/maven-wrapper-3.3.2.jar
IF NOT EXIST "%MAVEN_PROJECTBASEDIR%\.mvn\wrapper" mkdir "%MAVEN_PROJECTBASEDIR%\.mvn\wrapper"
IF NOT EXIST "%MAVEN_PROJECTBASEDIR%\.mvn\wrapper\maven-wrapper.jar" (
  powershell -Command "&{"^
    "$webclient = new-object System.Net.WebClient;"^
    "if (-not ([string]::IsNullOrEmpty('%MVNW_USERNAME%') -and [string]::IsNullOrEmpty('%MVNW_PASSWORD%'))) {"^
    "$webclient.Credentials = new-object System.Net.NetworkCredential('%MVNW_USERNAME%', '%MVNW_PASSWORD%');"^
    "}"^
    "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;"^
    "$webclient.DownloadFile('%MVNW_DOWNLOAD_URL%', '%MAVEN_PROJECTBASEDIR%\.mvn\wrapper\maven-wrapper.jar')"^
    "}"
)

:executeWrapper
@IF EXIST "%MAVEN_PROJECTBASEDIR%\.mvn\wrapper\maven-wrapper.jar" (
  "%JAVA_EXE%" %MAVEN_OPTS% %DEFAULT_JVM_OPTS% ^
    -classpath "%MAVEN_PROJECTBASEDIR%\.mvn\wrapper\maven-wrapper.jar" ^
    "-Dmaven.multiModuleProjectDirectory=%MAVEN_PROJECTBASEDIR%" ^
    org.apache.maven.wrapper.MavenWrapperMain %MAVEN_CMD_LINE_ARGS%
) ELSE (
  echo.
  echo Error: Maven wrapper jar not found.
  echo Please run: mvn -N wrapper:wrapper
  echo.
  goto error
)

if ERRORLEVEL 1 goto error
goto end

:wrapperDownloadError
echo.
echo ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.
echo.
echo Please set the JAVA_HOME variable in your environment to match the
echo location of your Java installation.

:error
set ERROR_CODE=1

:end
@endlocal & SET ERROR_CODE=%ERROR_CODE%

@IF "%MAVEN_BATCH_PAUSE%"=="on" pause

@IF "%MAVEN_SKIP_RC%"=="" (
  @IF EXIST "%USERPROFILE%\mavenrc_post.cmd" call "%USERPROFILE%\mavenrc_post.cmd"
)

@EXIT /B %ERROR_CODE%

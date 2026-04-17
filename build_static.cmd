@ECHO OFF
SETLOCAL EnableDelayedExpansion

REM Build libarchive with static binaries on Windows using MSVC
REM Usage: build_static.cmd [deplibs|configure|build|all]

SET SCRIPT_DIR=%~dp0
SET LIBARCHIVE_DIR=%SCRIPT_DIR%libarchive
SET BUILD_DIR=%SCRIPT_DIR%build_static
SET INSTALL_DIR=%SCRIPT_DIR%install_static

REM Dependency versions (from libarchive CI)
SET ZLIB_VERSION=1.3
SET BZIP2_VERSION=1ea1ac188ad4b9cb662e3f8314673c63df95a589
SET XZ_VERSION=5.6.3
SET ZSTD_VERSION=1.5.5
SET LZ4_VERSION=1.10.0

REM Use cmake from PATH (provided by VS install or CI runner)
SET CMAKE_EXE=cmake

REM Capture ProgramFiles(x86) to a safe variable name -- the ()
REM in the variable name breaks batch IF (...) blocks otherwise.
SET "PF86=%ProgramFiles(x86)%"

REM Set up Visual Studio environment if not already set up
IF DEFINED VCINSTALLDIR (
    ECHO VS environment already configured: %VCINSTALLDIR%
    GOTO :vs_ready
)

SET "VSWHERE=%PF86%\Microsoft Visual Studio\Installer\vswhere.exe"
IF NOT EXIST "%VSWHERE%" (
    ECHO Could not find vswhere.exe at "%VSWHERE%"
    EXIT /b 1
)
FOR /F "usebackq tokens=*" %%i IN (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) DO SET "VS_PATH=%%i"
IF NOT DEFINED VS_PATH (
    ECHO Could not locate a Visual Studio installation with the C++ x64 toolset
    EXIT /b 1
)
CALL "%VS_PATH%\VC\Auxiliary\Build\vcvarsall.bat" x64
IF ERRORLEVEL 1 (
    ECHO Failed to set up Visual Studio environment
    EXIT /b 1
)

:vs_ready

IF "%1"=="" (
    ECHO Usage: %~nx0 deplibs^|configure^|build^|all
    ECHO   deplibs   - Download and build dependencies
    ECHO   configure - Configure libarchive
    ECHO   build     - Build libarchive
    ECHO   all       - Do all steps
    EXIT /b 0
)

IF "%1"=="all" (
    CALL :deplibs
    IF ERRORLEVEL 1 EXIT /b 1
    CALL :configure
    IF ERRORLEVEL 1 EXIT /b 1
    CALL :build
    IF ERRORLEVEL 1 EXIT /b 1
    GOTO :done
)

IF "%1"=="deplibs" (
    CALL :deplibs
    EXIT /b !ERRORLEVEL!
)

IF "%1"=="configure" (
    CALL :configure
    EXIT /b !ERRORLEVEL!
)

IF "%1"=="build" (
    CALL :build
    EXIT /b !ERRORLEVEL!
)

ECHO Unknown command: %1
EXIT /b 1

:deplibs
ECHO.
ECHO ========================================
ECHO Building dependencies as static libraries
ECHO ========================================

IF NOT EXIST "%BUILD_DIR%\libs" MKDIR "%BUILD_DIR%\libs"
CD /D "%BUILD_DIR%\libs"

REM Download and build zlib
IF NOT EXIST zlib-%ZLIB_VERSION%.zip (
    ECHO Downloading zlib %ZLIB_VERSION%...
    curl -L -o zlib-%ZLIB_VERSION%.zip https://github.com/libarchive/zlib/archive/v%ZLIB_VERSION%.zip
    IF ERRORLEVEL 1 EXIT /b 1
)
IF NOT EXIST zlib-%ZLIB_VERSION% (
    ECHO Extracting zlib...
    powershell -Command "Expand-Archive -Path 'zlib-%ZLIB_VERSION%.zip' -DestinationPath '.' -Force"
    IF ERRORLEVEL 1 EXIT /b 1
)
IF NOT EXIST "%INSTALL_DIR%\lib\zlibstatic.lib" (
    ECHO Building zlib...
    CD zlib-%ZLIB_VERSION%
    IF EXIST build RD /S /Q build
    MKDIR build
    CD build
    "%CMAKE_EXE%" -G "Visual Studio 17 2022" -A x64 ^
        -DCMAKE_INSTALL_PREFIX="%INSTALL_DIR%" ^
        -DCMAKE_POLICY_DEFAULT_CMP0091=NEW ^
        -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
        -DCMAKE_C_FLAGS_RELEASE="/MT /O2 /Ob2 /DNDEBUG" ^
        ..
    IF ERRORLEVEL 1 EXIT /b 1
    "%CMAKE_EXE%" --build . --config Release
    IF ERRORLEVEL 1 EXIT /b 1
    "%CMAKE_EXE%" --install . --config Release
    IF ERRORLEVEL 1 EXIT /b 1
    CD "%BUILD_DIR%\libs"
)

REM Download and build bzip2
IF NOT EXIST bzip2-%BZIP2_VERSION%.zip (
    ECHO Downloading bzip2...
    curl -L -o bzip2-%BZIP2_VERSION%.zip https://github.com/libarchive/bzip2/archive/%BZIP2_VERSION%.zip
    IF ERRORLEVEL 1 EXIT /b 1
)
IF NOT EXIST bzip2-%BZIP2_VERSION% (
    ECHO Extracting bzip2...
    powershell -Command "Expand-Archive -Path 'bzip2-%BZIP2_VERSION%.zip' -DestinationPath '.' -Force"
    IF ERRORLEVEL 1 EXIT /b 1
)
IF NOT EXIST "%INSTALL_DIR%\lib\bz2_static.lib" (
    ECHO Building bzip2...
    CD bzip2-%BZIP2_VERSION%
    IF EXIST build RD /S /Q build
    MKDIR build
    CD build
    "%CMAKE_EXE%" -G "Visual Studio 17 2022" -A x64 ^
        -DCMAKE_INSTALL_PREFIX="%INSTALL_DIR%" ^
        -DCMAKE_POLICY_DEFAULT_CMP0091=NEW ^
        -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
        -DCMAKE_C_FLAGS_RELEASE="/MT /O2 /Ob2 /DNDEBUG" ^
        -DENABLE_LIB_ONLY=ON ^
        -DENABLE_SHARED_LIB=OFF ^
        -DENABLE_STATIC_LIB=ON ^
        ..
    IF ERRORLEVEL 1 EXIT /b 1
    "%CMAKE_EXE%" --build . --config Release
    IF ERRORLEVEL 1 EXIT /b 1
    "%CMAKE_EXE%" --install . --config Release
    IF ERRORLEVEL 1 EXIT /b 1
    CD "%BUILD_DIR%\libs"
)

REM Download and build xz (liblzma)
IF NOT EXIST xz-%XZ_VERSION%.zip (
    ECHO Downloading xz %XZ_VERSION%...
    curl -L -o xz-%XZ_VERSION%.zip https://github.com/libarchive/xz/archive/v%XZ_VERSION%.zip
    IF ERRORLEVEL 1 EXIT /b 1
)
IF NOT EXIST xz-%XZ_VERSION% (
    ECHO Extracting xz...
    powershell -Command "Expand-Archive -Path 'xz-%XZ_VERSION%.zip' -DestinationPath '.' -Force"
    IF ERRORLEVEL 1 EXIT /b 1
)
IF NOT EXIST "%INSTALL_DIR%\lib\lzma.lib" (
    ECHO Building xz/liblzma...
    CD xz-%XZ_VERSION%
    IF EXIST build RD /S /Q build
    MKDIR build
    CD build
    "%CMAKE_EXE%" -G "Visual Studio 17 2022" -A x64 ^
        -DCMAKE_INSTALL_PREFIX="%INSTALL_DIR%" ^
        -DCMAKE_POLICY_DEFAULT_CMP0091=NEW ^
        -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
        -DCMAKE_C_FLAGS_RELEASE="/MT /O2 /Ob2 /DNDEBUG" ^
        -DBUILD_SHARED_LIBS=OFF ^
        ..
    IF ERRORLEVEL 1 EXIT /b 1
    "%CMAKE_EXE%" --build . --config Release
    IF ERRORLEVEL 1 EXIT /b 1
    "%CMAKE_EXE%" --install . --config Release
    IF ERRORLEVEL 1 EXIT /b 1
    CD "%BUILD_DIR%\libs"
)

REM Download and build zstd
IF NOT EXIST zstd-%ZSTD_VERSION%.zip (
    ECHO Downloading zstd %ZSTD_VERSION%...
    curl -L -o zstd-%ZSTD_VERSION%.zip https://github.com/facebook/zstd/archive/refs/tags/v%ZSTD_VERSION%.zip
    IF ERRORLEVEL 1 EXIT /b 1
)
IF NOT EXIST zstd-%ZSTD_VERSION% (
    ECHO Extracting zstd...
    powershell -Command "Expand-Archive -Path 'zstd-%ZSTD_VERSION%.zip' -DestinationPath '.' -Force"
    IF ERRORLEVEL 1 EXIT /b 1
)
IF NOT EXIST "%INSTALL_DIR%\lib\zstd_static.lib" (
    ECHO Building zstd...
    CD zstd-%ZSTD_VERSION%\build\cmake
    IF EXIST build RD /S /Q build
    MKDIR build
    CD build
    "%CMAKE_EXE%" -G "Visual Studio 17 2022" -A x64 ^
        -DCMAKE_INSTALL_PREFIX="%INSTALL_DIR%" ^
        -DCMAKE_POLICY_DEFAULT_CMP0091=NEW ^
        -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
        -DCMAKE_C_FLAGS_RELEASE="/MT /O2 /Ob2 /DNDEBUG" ^
        -DZSTD_BUILD_SHARED=OFF ^
        -DZSTD_BUILD_STATIC=ON ^
        ..
    IF ERRORLEVEL 1 EXIT /b 1
    "%CMAKE_EXE%" --build . --config Release
    IF ERRORLEVEL 1 EXIT /b 1
    "%CMAKE_EXE%" --install . --config Release
    IF ERRORLEVEL 1 EXIT /b 1
    CD "%BUILD_DIR%\libs"
)

REM Download and build LZ4
IF NOT EXIST lz4-%LZ4_VERSION%.zip (
    ECHO Downloading lz4 %LZ4_VERSION%...
    curl -L -o lz4-%LZ4_VERSION%.zip https://github.com/lz4/lz4/archive/refs/tags/v%LZ4_VERSION%.zip
    IF ERRORLEVEL 1 EXIT /b 1
)
IF NOT EXIST lz4-%LZ4_VERSION% (
    ECHO Extracting lz4...
    powershell -Command "Expand-Archive -Path 'lz4-%LZ4_VERSION%.zip' -DestinationPath '.' -Force"
    IF ERRORLEVEL 1 EXIT /b 1
)
IF NOT EXIST "%INSTALL_DIR%\lib\lz4.lib" (
    ECHO Building lz4...
    CD lz4-%LZ4_VERSION%\build\cmake
    IF EXIST build RD /S /Q build
    MKDIR build
    CD build
    "%CMAKE_EXE%" -G "Visual Studio 17 2022" -A x64 ^
        -DCMAKE_INSTALL_PREFIX="%INSTALL_DIR%" ^
        -DCMAKE_POLICY_DEFAULT_CMP0091=NEW ^
        -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
        -DCMAKE_C_FLAGS_RELEASE="/MT /O2 /Ob2 /DNDEBUG" ^
        -DBUILD_SHARED_LIBS=OFF ^
        -DBUILD_STATIC_LIBS=ON ^
        -DLZ4_BUILD_CLI=OFF ^
        -DLZ4_BUILD_LEGACY_LZ4C=OFF ^
        ..
    IF ERRORLEVEL 1 EXIT /b 1
    "%CMAKE_EXE%" --build . --config Release
    IF ERRORLEVEL 1 EXIT /b 1
    "%CMAKE_EXE%" --install . --config Release
    IF ERRORLEVEL 1 EXIT /b 1
    CD "%BUILD_DIR%\libs"
)

ECHO.
ECHO Dependencies built successfully!
EXIT /b 0

:configure
ECHO.
ECHO ========================================
ECHO Configuring libarchive
ECHO ========================================

IF NOT EXIST "%BUILD_DIR%\libarchive" MKDIR "%BUILD_DIR%\libarchive"
CD /D "%BUILD_DIR%\libarchive"

REM Convert paths to forward slashes for CMake
SET INSTALL_DIR_CMAKE=%INSTALL_DIR:\=/%
SET LIBARCHIVE_DIR_CMAKE=%LIBARCHIVE_DIR:\=/%

"%CMAKE_EXE%" -G "Visual Studio 17 2022" -A x64 ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_INSTALL_PREFIX="%INSTALL_DIR_CMAKE%" ^
    -DCMAKE_POLICY_DEFAULT_CMP0091=NEW ^
    -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
    -DCMAKE_C_FLAGS_RELEASE="/MT /O2 /Ob2 /DNDEBUG" ^
    -DBUILD_SHARED_LIBS=OFF ^
    -DENABLE_WERROR=OFF ^
    -DENABLE_TEST=OFF ^
    -DZLIB_LIBRARY="%INSTALL_DIR_CMAKE%/lib/zlibstatic.lib" ^
    -DZLIB_INCLUDE_DIR="%INSTALL_DIR_CMAKE%/include" ^
    -DBZIP2_LIBRARIES="%INSTALL_DIR_CMAKE%/lib/bz2_static.lib" ^
    -DBZIP2_INCLUDE_DIR="%INSTALL_DIR_CMAKE%/include" ^
    -DLIBLZMA_LIBRARY="%INSTALL_DIR_CMAKE%/lib/lzma.lib" ^
    -DLIBLZMA_INCLUDE_DIR="%INSTALL_DIR_CMAKE%/include" ^
    -DZSTD_LIBRARY="%INSTALL_DIR_CMAKE%/lib/zstd_static.lib" ^
    -DZSTD_INCLUDE_DIR="%INSTALL_DIR_CMAKE%/include" ^
    -DLZ4_LIBRARY="%INSTALL_DIR_CMAKE%/lib/lz4.lib" ^
    -DLZ4_INCLUDE_DIR="%INSTALL_DIR_CMAKE%/include" ^
    -DENABLE_LZ4=ON ^
    -DENABLE_CNG=ON ^
    -DENABLE_OPENSSL=OFF ^
    -DENABLE_LIBB2=OFF ^
    -DENABLE_LIBXML2=OFF ^
    -DENABLE_EXPAT=OFF ^
    "%LIBARCHIVE_DIR_CMAKE%"

IF ERRORLEVEL 1 EXIT /b 1
ECHO.
ECHO Configuration complete!
EXIT /b 0

:build
ECHO.
ECHO ========================================
ECHO Building libarchive
ECHO ========================================

CD /D "%BUILD_DIR%\libarchive"
"%CMAKE_EXE%" --build . --config Release
IF ERRORLEVEL 1 EXIT /b 1

"%CMAKE_EXE%" --install . --config Release
IF ERRORLEVEL 1 EXIT /b 1

ECHO.
ECHO ========================================
ECHO Build complete!
ECHO ========================================
ECHO.
ECHO Static binaries installed to: %INSTALL_DIR%
ECHO.
ECHO Executables:
DIR /B "%INSTALL_DIR%\bin\*.exe" 2>NUL
ECHO.
EXIT /b 0

:done
ECHO.
ECHO ========================================
ECHO ALL DONE!
ECHO ========================================
ECHO Static binaries are in: %INSTALL_DIR%
EXIT /b 0

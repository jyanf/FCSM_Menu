@echo off
setlocal

echo.
echo ==========================================
echo        animpattern XML Diff Tool
echo ==========================================
echo.

REM ---------- 检查 Python ----------
where python >nul 2>nul
if %errorlevel% neq 0 (
echo [ERROR] Python 未安装或未加入 PATH
echo 请先安装 Python
pause
exit /b
)

REM ---------- 检查脚本 ----------
if not exist animpattern_diff.py (
echo [ERROR] 未找到 animpattern_diff.py
echo 请确保 CMD 与 Python 脚本在同一目录
pause
exit /b
)

REM ---------- 参数模式 ----------
if not "%1"=="" goto ARG_MODE

echo 使用方法:
echo.
echo    animpattern_diff A.xml B.xml diff.xml
echo.
echo 或直接运行进入交互模式
echo.

set /p AXML=请输入 原始XML (A.xml):
if not exist "%AXML%" (
echo [ERROR] 文件不存在: %AXML%
pause
exit /b
)

set /p BXML=请输入 修改XML (B.xml):
if not exist "%BXML%" (
echo [ERROR] 文件不存在: %BXML%
pause
exit /b
)

set /p OUTXML=请输入 输出diff文件名 [diff.xml]:

if "%OUTXML%"=="" set OUTXML=diff.xml

echo.
echo 正在生成 diff...
echo.

python animpattern_diff.py "%AXML%" "%BXML%" -o "%OUTXML%"

echo.
echo 完成
echo 输出文件: %OUTXML%
echo.

pause
exit /b

:ARG_MODE

set AXML=%1
set BXML=%2
set OUTXML=%3

if "%AXML%"=="" (
echo [ERROR] 缺少 A.xml
exit /b
)

if "%BXML%"=="" (
echo [ERROR] 缺少 B.xml
exit /b
)

if "%OUTXML%"=="" set OUTXML=diff.xml

if not exist "%AXML%" (
echo [ERROR] 文件不存在: %AXML%
exit /b
)

if not exist "%BXML%" (
echo [ERROR] 文件不存在: %BXML%
exit /b
)

echo 正在生成 diff...
python animpattern_diff.py "%AXML%" "%BXML%" -o "%OUTXML%"

echo.
echo 完成
echo 输出文件: %OUTXML%
echo.

endlocal

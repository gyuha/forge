: << 'CMDBLOCK'
@echo off
REM Cross-platform polyglot wrapper for forge hook bodies.
REM On Windows: cmd.exe runs this batch portion, which finds a runtime itself.
REM On Unix: the shell interprets this file as a script (`:` is a no-op, and the
REM heredoc swallows the batch block).
REM
REM Pattern borrowed from obra/superpowers (hooks/run-hook.cmd), MIT licensed —
REM Copyright (c) Jesse Vincent. Extended here with a node fallback so a Windows
REM box without git-bash still gets the hook via forge's .js twin (ADR-0022).
REM
REM Dispatch: run-hook <name> [args...]  ->  scripts/forge-hook-<name>.sh (bash)
REM                                      or  scripts/forge-hook-<name>.js (node)
REM No runtime / unknown name -> exit 0 silently: a missing hook notice is
REM harmless (it degrades to the pre-hook status quo), but a failing hook would
REM break session start.

if "%~1"=="" exit /b 0

set "HOOK_DIR=%~dp0"
set "NAME=%~1"
set "SH=%HOOK_DIR%..\scripts\forge-hook-%NAME%.sh"
set "JS=%HOOK_DIR%..\scripts\forge-hook-%NAME%.js"

REM The hook bodies read forge state from the current directory, so anchor to the
REM project dir Claude Code hands us when it is set (do not rely on inherited cwd).
if defined CLAUDE_PROJECT_DIR (
    if exist "%CLAUDE_PROJECT_DIR%" cd /d "%CLAUDE_PROJECT_DIR%"
)

REM Git for Windows bash in the standard locations
if exist "C:\Program Files\Git\bin\bash.exe" (
    if exist "%SH%" (
        "C:\Program Files\Git\bin\bash.exe" "%SH%" %2 %3 %4 %5 %6 %7 %8 %9
        exit /b 0
    )
)
if exist "C:\Program Files (x86)\Git\bin\bash.exe" (
    if exist "%SH%" (
        "C:\Program Files (x86)\Git\bin\bash.exe" "%SH%" %2 %3 %4 %5 %6 %7 %8 %9
        exit /b 0
    )
)

REM bash on PATH (user-installed Git Bash, MSYS2, Cygwin)
where bash >nul 2>nul
if %ERRORLEVEL% equ 0 (
    if exist "%SH%" (
        bash "%SH%" %2 %3 %4 %5 %6 %7 %8 %9
        exit /b 0
    )
)

REM node fallback — forge ships a .js twin of every script (ADR-0022)
where node >nul 2>nul
if %ERRORLEVEL% equ 0 (
    if exist "%JS%" (
        node "%JS%" %2 %3 %4 %5 %6 %7 %8 %9
        exit /b 0
    )
)

exit /b 0
CMDBLOCK

# --- Unix path ---------------------------------------------------------------
# Prefer the bash primary, fall back to the node twin, else stay silent.
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
NAME="${1:-}"
[ -n "$NAME" ] || exit 0
shift

SH="$HOOK_DIR/../scripts/forge-hook-$NAME.sh"
JS="$HOOK_DIR/../scripts/forge-hook-$NAME.js"

# The hook bodies read forge state from the current directory, so anchor to the
# project dir Claude Code hands us when it is set (do not rely on inherited cwd).
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "${CLAUDE_PROJECT_DIR}" ]; then
  cd "${CLAUDE_PROJECT_DIR}" || exit 0
fi

if [ -f "$SH" ] && command -v bash >/dev/null 2>&1; then
  exec bash "$SH" "$@"
fi
if [ -f "$JS" ] && command -v node >/dev/null 2>&1; then
  exec node "$JS" "$@"
fi
exit 0

@echo off
REM One-time setup: save INTDEVFAM@DWMSDEV for oracle-sqlcl MCP (requires -savepwd).
REM Run this once, then restart the oracle-sqlcl MCP server in Cursor.

set SQLCL=C:\Users\kumvik01\OneDrive - CSG Systems Inc\Projects\AICursor_Workspace\sqlcl\bin\sql.exe

echo Saving named connection INTDEVFAM to %%USERPROFILE%%\.dbtools ...
echo conn -save INTDEVFAM -savepwd INTDEVFAM/INTDEVFAM@//dubdevxorcd37:1521/DWMSDEV | "%SQLCL%" -L

if errorlevel 1 (
  echo.
  echo FAILED: Could not save or connect. Check VPN, host dubdevxorcd37, and credentials.
  exit /b 1
)

echo.
echo SUCCESS: Connection INTDEVFAM saved.
echo Next: Cursor ^> MCP ^> oracle-sqlcl ^> Restart Server, then re-run /logiq-scan.
exit /b 0

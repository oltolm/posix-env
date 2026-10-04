@rem Hard-links each utility name to coreutils.exe.
@for /f "usebackq delims=" %%n in ("%PREFIX%\share\uutils-coreutils\utilities.txt") do @if not exist "%PREFIX%\bin\%%n.exe" mklink /h "%PREFIX%\bin\%%n.exe" "%PREFIX%\bin\coreutils.exe" >nul

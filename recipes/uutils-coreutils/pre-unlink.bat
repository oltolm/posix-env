@rem Removes the hard links made by the post-link script.
@for /f "usebackq delims=" %%n in ("%PREFIX%\share\uutils-coreutils\utilities.txt") do @if exist "%PREFIX%\bin\%%n.exe" del /f "%PREFIX%\bin\%%n.exe"

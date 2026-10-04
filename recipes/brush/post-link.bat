@rem Hard-links sh.exe and bash.exe to brush.exe.
@for %%n in (sh bash) do @if not exist "%PREFIX%\bin\%%n.exe" mklink /h "%PREFIX%\bin\%%n.exe" "%PREFIX%\bin\brush.exe" >nul

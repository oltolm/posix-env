@rem Removes the hard links made by the post-link script.
@for %%n in (sh bash) do @if exist "%PREFIX%\bin\%%n.exe" del /f "%PREFIX%\bin\%%n.exe"

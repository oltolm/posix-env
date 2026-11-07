# posix-env

posix-env is a native POSIX build environment for 64-bit Windows. It combines
the [brush](https://github.com/reubeno/brush) shell, native Windows ports of
POSIX utilities, GNU build tools and an external MinGW-w64 UCRT toolchain.
The programs run without the MSYS or Cygwin runtime, `fork()` emulation or
automatic path translation.

The environment is distributed as `.conda` packages and managed by its own
micromamba executable. Package operations use only the posix-env channel.

> **Status:** pre-release. The recipes and local build/install workflow are
> usable, but the public package channel has not been deployed yet.

## Why posix-env?

Autotools projects start many short-lived processes. Native Windows programs
avoid the process-creation and path-conversion overhead of an emulated POSIX
runtime while retaining the shell and utilities expected by common build
systems.

posix-env is deliberately a build environment rather than a Unix compatibility
layer. Paths remain native Windows paths written with `/`, for example
`C:/Users/me/posix-env`; `/usr`, `/bin` and `/tmp` do not exist.

## Requirements

- 64-bit Windows.
- A MinGW-w64 UCRT toolchain. The default is MSYS2's UCRT64 toolchain in
  `C:\msys64\ucrt64\bin`; set `POSIX_ENV_TOOLCHAIN` to use another one.
- Git for builds that fetch Git sources. Set `POSIX_ENV_GIT` when it is not in
  `%ProgramFiles%\Git\cmd`.
- Windows Developer Mode when builds need to create symbolic links.

## Installation

The first public release will provide the standalone `install.ps1` bootstrap.
Installation will use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

The installer verifies its pinned micromamba download, creates
`%USERPROFILE%\posix-env` from the published channel, installs the default
packages and runs setup. Use `-InstallDir DIR` to select another location,
`-Channel URL` to select another channel, or `-NoUserIntegration` to avoid
adding the user PATH, Start menu and Windows Terminal entries.

After installation:

```console
posix-env run                  # open the shell
posix-env run make -j8         # run one command
posix-env install dejagnu      # add a package
posix-env update               # update the environment
posix-env help                 # list all commands
```

## Building from source

Download the pinned build tools, then build one or more recipes into the local
`output\` channel:

```console
powershell -ExecutionPolicy Bypass -File tools\fetch.ps1
build RECIPE [RECIPE...] [-- rattler-build options]
```

`POSIX_ENV_TOOLCHAIN` selects the external compiler's `bin` directory. Builds
use only packages already present in the local channel; they do not fall back
to conda-forge.

GitHub Actions builds recipe directories changed by pushes to `master` or by
pull requests. A manual run accepts a space- or comma-separated recipe list.
Each clean build uses the published posix-env channel for build dependencies
and retains its resulting packages as a workflow artifact for 14 days.

See [the full documentation](docs/posix-env.md) for package details, build
conventions, environment behavior, performance measurements and current
limitations. Open work is tracked in [TODO.md](TODO.md).

## License

Original posix-env code and documentation are available under the
[MIT License](LICENSE). Packaged third-party projects and patches derived from
them remain subject to their respective upstream licenses; each recipe records
its package license.

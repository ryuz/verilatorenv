# verilatorenv

A pyenv-style Verilator version manager. Clone the repository, add `bin` to
your PATH, and use the regular `verilator` command. No package manager,
Python environment, or administrator privileges are needed for verilatorenv.
Verilator itself is built from its official GitHub release tags.

## Setup

```bash
git clone <repository-url> "$HOME/.verilatorenv"
export PATH="$HOME/.verilatorenv/bin:$PATH"
```

Add the PATH export to your shell startup file. The `bin` directory must come
before any existing Verilator installation in PATH. Bash 4.4 or newer is
required to run the CLI. Shell integration supports Bash and Zsh.

By default, settings, installed versions, build logs, and shims live in the
cloned repository. To store them separately, set `VERILATORENV_ROOT` before
running verilatorenv:

```bash
export VERILATORENV_ROOT="$HOME/.local/share/verilatorenv"
```

`bin` already contains wrappers for `verilator`, `verilator_bin`,
`verilator_coverage`, `verilator_gantt`, `verilator_profcfunc`, and
`verilator_includer`, so the normal workflow needs no shell initialization.
Optional initialization adds generated shims for every installed executable
and enables the `shell` command:

```bash
eval "$(verilatorenv init - bash)"
# For Zsh instead:
eval "$(verilatorenv init - zsh)"
```

Use `verilatorenv init --path` for PATH setup without a shell function.

## Build Requirements

Install Git, GNU Make, Autoconf, Perl, Flex, Bison, and a C++ compiler compatible
with the chosen Verilator release. Standard Unix utilities such as `sed`,
`sort`, `tee`, and `mktemp` are also required. On Ubuntu/Debian, a typical setup
is:

```bash
sudo apt-get install git build-essential autoconf flex bison perl
```

Verilator releases can have additional requirements. SystemC is optional and
must be installed separately when your workflow needs it. The build follows
the release's normal `autoconf`, `configure`, `make`, and `make install` steps.
The initial clone needs access to GitHub.

## Usage

```bash
verilatorenv install --list
verilatorenv install 5.042
verilatorenv install v5.040       # The leading v is optional

verilatorenv global 5.042
verilator --version

cd my-project
verilatorenv local 5.040
verilator --version
cd src                          # Inherits my-project/.verilator-version
verilator --version

verilatorenv local --unset       # Removes the file in the current directory
verilatorenv global system      # Use the existing installation from PATH
verilatorenv uninstall 5.040     # Confirmation required
verilatorenv uninstall -f 5.040  # Non-interactive; missing versions are OK
```

The examples require both versions to be installed first. `local --unset`
only removes the current directory's file; ancestor settings still apply.
To override a parent's version with the system installation, use
`verilatorenv local system`.

Selection priority, highest first:

1. `VERILATORENV_VERSION`, including `verilatorenv shell` overrides.
2. The nearest `.verilator-version`, searching from the current directory
   through all parent directories up to `/`.
3. The global version in `$VERILATORENV_ROOT/version`.
4. `system`, found in PATH after removing this manager's wrappers, shims,
   and managed version `bin` directories.

`VERILATORENV_DIR` changes the starting directory for the local-file search.
Files contain one version, with optional blank lines and `#` comments.
Versions must be installed before setting them with `global`, `local`, or
`shell`. A stale or invalid setting is an error, never a silent fallback.
Uninstall does not rewrite project files or the global setting: select another
version if you remove the selected one.

With shell integration enabled:

```bash
verilatorenv shell 5.040
verilatorenv shell               # Show the shell override
verilatorenv shell --unset
```

Without shell integration, use an environment variable:

```bash
VERILATORENV_VERSION=5.040 verilator --version
```

Existing shell aliases or functions named `verilator` take precedence over
PATH; remove them when using these wrappers. Wrappers clear `VERILATOR_ROOT`
before execution so a stale upstream setting cannot select a different
installation. `VERILATORENV_ROOT` is the manager's data directory, not the
upstream `VERILATOR_ROOT` variable.

## Other Commands

```bash
verilatorenv versions            # Installed versions, selection marked *
verilatorenv versions --bare
verilatorenv version             # Selected version and selection origin
verilatorenv version-name
verilatorenv version-origin
verilatorenv which verilator
verilatorenv whence verilator_coverage
verilatorenv prefix [VERSION]
verilatorenv root
verilatorenv exec verilator --lint-only design.sv
verilatorenv rehash
verilatorenv commands
verilatorenv help
```

`exec` runs an executable belonging to the selected version, preserving its
arguments and exit status. `rehash` regenerates executable shims and is run
automatically after installation and removal. The `shims` directory is managed
by verilatorenv; do not put custom scripts in it.

## Installation Options

```bash
verilatorenv install --skip-existing 5.042
verilatorenv install --force 5.042
VERILATORENV_JOBS=2 verilatorenv install 5.042
VERILATORENV_CONFIGURE_OPTS="--enable-ccache" verilatorenv install 5.042
VERILATORENV_MAKE_OPTS="CXX=clang++" verilatorenv install 5.042
```

`VERILATORENV_JOBS` defaults to the number of online CPUs (or 2 if unavailable).
Choose a smaller number on memory-constrained hosts. Configure and Make options
are whitespace-separated argument lists, not shell code; embedded quoting and
arguments containing spaces are not supported. Prefix and DESTDIR overrides
are reserved for the manager. Compiler variables such as `CC`, `CXX`, and
`CXXFLAGS` can also be exported normally.

Builds use temporary source and staging directories under `cache`. Build output
is shown on the terminal and retained in `cache/<version>.<id>.log`, including
on failure. A build failure leaves an existing installation untouched. New
installations are published only after `make install` has succeeded and the
staged `verilator --version` check passes. Temporary sources are removed after
the operation. Same-version installs/uninstalls are serialized with lock
directories. After an uncatchable termination such as `SIGKILL`, verify that no
operation is running before manually removing the corresponding directory in
`locks` or `.rehash-lock`.

The default source is `https://github.com/verilator/verilator.git`.
`VERILATORENV_REPOSITORY` can point to a trusted mirror with the same `vVERSION`
tag convention, and is used by the tests. Building executes code from that
repository; do not configure an untrusted source. Only tagged versions are
supported, not arbitrary branches or commits. Tags are not cryptographically
verified by this tool. Each setting selects a single version; pyenv's multiple
simultaneous versions and plugin API are not implemented.

Do not move the data root after installing: Verilator embeds its installation
prefix, and generated shims refer to the cloned CLI. Rebuild versions after a
root move, and run `rehash` after moving the cloned CLI.

## Tests

```bash
bash -n bin/* tests/run.sh
bash tests/run.sh
shellcheck bin/* tests/run.sh
```

The integration suite runs offline in temporary directories. It builds a tiny
tagged Git fixture using Autoconf and Make, and tests selection, wrappers,
system lookup, shell integration, space-containing paths, invalid settings,
build failures, force rebuilds, locks, removal, and shim cleanup. The suite
requires the build tools listed above; ShellCheck is an optional local linter.
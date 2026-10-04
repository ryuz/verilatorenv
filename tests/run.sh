#!/usr/bin/env bash
set -euo pipefail

PROJECT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
SANDBOX=$(mktemp -d)
trap 'rm -rf -- "$SANDBOX"' EXIT
export VERILATORENV_ROOT="$SANDBOX/root with spaces"
export PATH="$PROJECT/bin:$PATH"
unset VERILATORENV_VERSION VERILATORENV_DIR
mkdir -p "$VERILATORENV_ROOT/versions/5.040/bin" "$VERILATORENV_ROOT/versions/5.042/bin" "$SANDBOX/project/child"
for version in 5.040 5.042; do
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s:$*"\n' "$version" > "$VERILATORENV_ROOT/versions/$version/bin/verilator"
    chmod +x "$VERILATORENV_ROOT/versions/$version/bin/verilator"
done

assert_equal() {
    [[ $1 == "$2" ]] || { printf 'FAIL: expected <%s>, got <%s>\n' "$2" "$1" >&2; exit 1; }
}

expect_failure() {
    if "$@" > "$SANDBOX/failure.log" 2>&1; then
        printf 'FAIL: command unexpectedly succeeded: %s\n' "$*" >&2
        exit 1
    fi
}

cd "$SANDBOX/project"
verilatorenv global 5.040
assert_equal "$(verilatorenv version-name)" 5.040
verilatorenv local v5.042
cd child
assert_equal "$(verilatorenv version-name)" 5.042
assert_equal "$(verilator --version)" '5.042:--version'
assert_equal "$(VERILATORENV_VERSION=5.040 verilator --version)" '5.040:--version'
assert_equal "$(verilatorenv version-origin)" "$SANDBOX/project/.verilator-version"
if VERILATORENV_VERSION=missing verilator --version > /dev/null 2>&1; then
    printf 'FAIL: missing version silently fell back\n' >&2
    exit 1
fi
printf 'PASS: version selection and wrapper execution\n'

verilatorenv local 5.040
assert_equal "$(verilatorenv version-name)" 5.040
verilatorenv local --unset
assert_equal "$(verilatorenv version-name)" 5.042
cd ..
verilatorenv local --unset
assert_equal "$(verilatorenv version-name)" 5.040
assert_equal "$(verilatorenv global)" 5.040
assert_equal "$(verilatorenv which verilator)" "$VERILATORENV_ROOT/versions/5.040/bin/verilator"
assert_equal "$(verilatorenv prefix v5.042)" "$VERILATORENV_ROOT/versions/5.042"
assert_equal "$(verilatorenv whence verilator)" $'5.040\n5.042'
assert_equal "$(verilatorenv versions --bare)" $'system\n5.040\n5.042'
expect_failure verilatorenv global ../../outside
expect_failure verilatorenv local missing
expect_failure verilatorenv exec ../verilator
expect_failure verilatorenv uninstall -f system
printf '5.040 # comment\n' > .verilator-version
assert_equal "$(verilatorenv version-name)" 5.040
printf '5.040 5.042\n' > .verilator-version
expect_failure verilatorenv version-name
printf '# empty\n' > .verilator-version
expect_failure verilatorenv version-name
rm .verilator-version
assert_equal "$(VERILATORENV_DIR="$SANDBOX/project" verilatorenv version-name)" 5.040
printf 'PASS: configuration, introspection, and invalid inputs\n'

mkdir -p "$SANDBOX/system"
cat > "$SANDBOX/system/verilator" <<'SYSTEM'
#!/usr/bin/env bash
[[ -z ${VERILATOR_ROOT:-} ]] || exit 91
printf 'system:%s\n' "$*"
SYSTEM
chmod +x "$SANDBOX/system/verilator"
export PATH="$PROJECT/bin:$SANDBOX/system:$PATH"
assert_equal "$(VERILATORENV_VERSION=system VERILATOR_ROOT=/invalid verilator --version)" 'system:--version'
assert_equal "$(VERILATORENV_VERSION=system verilatorenv which verilator)" "$SANDBOX/system/verilator"
expect_failure env VERILATORENV_VERSION=system "$PROJECT/bin/verilatorenv" which missing-command-for-test
eval "$(verilatorenv init - bash)"
verilatorenv shell 5.042
assert_equal "$VERILATORENV_VERSION" 5.042
assert_equal "$(verilatorenv shell)" 5.042
assert_equal "$(verilator --version)" '5.042:--version'
expect_failure verilatorenv shell missing
assert_equal "$VERILATORENV_VERSION" 5.042
verilatorenv shell --unset
assert_equal "$(verilatorenv version-name)" 5.040
verilatorenv rehash
assert_equal "$("$VERILATORENV_ROOT/shims/verilator" --version)" '5.040:--version'
assert_equal "$(VERILATORENV_VERSION=system "$VERILATORENV_ROOT/shims/verilator" --version)" 'system:--version'
printf 'PASS: system fallback, shell integration, and shims\n'

FIXTURE="$SANDBOX/source"
mkdir -p "$FIXTURE"
cat > "$FIXTURE/configure.ac" <<'CONFIGURE'
AC_INIT([verilatorenv-test], [1.0])
AC_CONFIG_FILES([Makefile])
AC_OUTPUT
CONFIGURE
printf '%s\n' \
    'prefix = @prefix@' \
    'all:' \
    $'\t@test "$(VERILATORENV_TEST_FAIL_BUILD)" != 1' \
    'install:' \
    $'\tmkdir -p "$(DESTDIR)$(prefix)/bin"' \
    $'\tcp fixture-verilator "$(DESTDIR)$(prefix)/bin/verilator"' \
    $'\tcp fixture-verilator "$(DESTDIR)$(prefix)/bin/fixture-helper"' > "$FIXTURE/Makefile.in"
cat > "$FIXTURE/fixture-verilator" <<'EXECUTABLE'
#!/usr/bin/env bash
printf 'Verilator fixture %s\n' "$*"
EXECUTABLE
chmod +x "$FIXTURE/fixture-verilator"
git -C "$FIXTURE" init --quiet
git -C "$FIXTURE" add .
git -C "$FIXTURE" -c user.name=Test -c user.email=test@example.invalid commit --quiet -m fixture
git -C "$FIXTURE" tag v5.044
git -C "$FIXTURE" tag v5.046
export VERILATORENV_REPOSITORY="$FIXTURE"
export VERILATORENV_JOBS=2
assert_equal "$(verilatorenv install --list)" $'5.044\n5.046'
verilatorenv install v5.044 > "$SANDBOX/install.log" 2>&1 || { cat "$SANDBOX/install.log"; exit 1; }
assert_equal "$(VERILATORENV_VERSION=5.044 verilator --version)" 'Verilator fixture --version'
assert_equal "$(VERILATORENV_VERSION=5.044 fixture-helper arg)" 'Verilator fixture arg'
expect_failure verilatorenv install 5.044
verilatorenv install --skip-existing 5.044 > /dev/null
expect_failure env VERILATORENV_TEST_FAIL_BUILD=1 "$PROJECT/bin/verilatorenv" install --force 5.044
assert_equal "$(VERILATORENV_VERSION=5.044 verilator --version)" 'Verilator fixture --version'
[[ ! -e $VERILATORENV_ROOT/locks/5.044 ]] || { printf 'FAIL: lock leaked\n'; exit 1; }
expect_failure env VERILATORENV_TEST_FAIL_BUILD=1 "$PROJECT/bin/verilatorenv" install 5.046
[[ ! -e $VERILATORENV_ROOT/versions/5.046 ]] || { printf 'FAIL: failed install published\n'; exit 1; }
expect_failure env VERILATORENV_JOBS=0 "$PROJECT/bin/verilatorenv" install 5.046
expect_failure env VERILATORENV_CONFIGURE_OPTS=--prefix=/tmp/outside "$PROJECT/bin/verilatorenv" install 5.046
expect_failure verilatorenv install ../outside
expect_failure verilatorenv install system
mkdir "$VERILATORENV_ROOT/locks/5.044"
expect_failure verilatorenv uninstall -f 5.044
rmdir "$VERILATORENV_ROOT/locks/5.044"
verilatorenv install --force 5.044 > "$SANDBOX/reinstall.log" 2>&1 || { cat "$SANDBOX/reinstall.log"; exit 1; }
verilatorenv uninstall -f 5.044 > /dev/null
[[ ! -e $VERILATORENV_ROOT/versions/5.044 && ! -e $VERILATORENV_ROOT/shims/fixture-helper ]] || {
    printf 'FAIL: uninstall left installed files or stale shim\n' >&2
    exit 1
}
expect_failure verilatorenv uninstall 5.044
verilatorenv uninstall -f 5.044
expect_failure env VERILATORENV_VERSION=5.044 "$PROJECT/bin/verilator" --version
printf 'PASS: tag listing, install, rebuild rollback, locks, uninstall, and stale shims\n'
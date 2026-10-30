#!/bin/sh
# sh test/test.sh: checks installcanary.sh against fake npms. No network.
cd "$(dirname "$0")/.." || exit 1
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# A fake npm: real `npm` for pack/install, but reports the version in $FAKE_V.
cat > "$T/fakenpm" <<'F'
#!/bin/sh
[ "$1" = "--version" ] && { echo "$FAKE_V"; exit 0; }
exec npm "$@"
F
chmod +x "$T/fakenpm"

out=$(npm_config_ignore_scripts=false ./installcanary.sh); code=$?
check "scripts on, no delay: EXPOSED" '[ $code -eq 1 ] && echo "$out" | grep -q "install scripts    RAN"'

out=$(npm_config_ignore_scripts=true FAKE_V=11.10.0 npm_config_min_release_age=1 ./installcanary.sh -- "$T/fakenpm"); code=$?
check "scripts off, delay on a new enough npm: HELD" '[ $code -eq 0 ] && echo "$out" | grep -q "blocked" && echo "$out" | grep -q "1 day"'

out=$(npm_config_ignore_scripts=true FAKE_V=11.9.0 npm_config_min_release_age=1 ./installcanary.sh -- "$T/fakenpm"); code=$?
check "a delay on npm 11.9 is reported as ignored" '[ $code -eq 1 ] && echo "$out" | grep -q "ignored"'

out=$(npm_config_ignore_scripts=true FAKE_V=10.9.9 npm_config_min_release_age=1 ./installcanary.sh -- "$T/fakenpm"); code=$?
check "a delay on npm 10 is reported as ignored" '[ $code -eq 1 ] && echo "$out" | grep -q "ignored"'

out=$(./installcanary.sh -- false 2>&1); code=$?
check "an npm that doesn't run measures nothing" '[ $code -eq 3 ]'

./installcanary.sh --bogus >/dev/null 2>&1; code=$?
check "a bad argument is a usage error" '[ $code -eq 2 ]'

ls "$T" | grep -q POSTINSTALL && fail=1
check "the probe writes only inside its temp project" '! ls . | grep -q POSTINSTALL-RAN'
exit $fail

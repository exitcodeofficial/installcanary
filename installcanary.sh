#!/bin/sh
# installcanary.sh: would your npm run a package's install script, and install a release published minutes ago?
#   ./installcanary.sh                      check `npm` with your own config (~/.npmrc, project .npmrc, env)
#   ./installcanary.sh -- npx -y npm@12     check another npm
# Exit 0 HELD (scripts blocked and a release-age delay set), 1 EXPOSED, 2 usage, 3 error (measured nothing)
set -u
NPM="npm"
if [ $# -gt 0 ]; then
  [ "$1" = "--" ] && [ $# -gt 1 ] || { sed -n '3,5p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
  shift; NPM="$*"
fi
T=$(mktemp -d) || exit 3
trap 'rm -rf "$T"' EXIT
export npm_config_logs_dir="$T/logs" npm_config_update_notifier=false

# A harmless package: its postinstall writes one file into the project that installs it. Nothing else.
mkdir -p "$T/pkg" "$T/app"
cat > "$T/pkg/package.json" <<'PKG'
{ "name": "installcanary-probe", "version": "1.0.0",
  "scripts": { "postinstall": "node -e \"require('fs').writeFileSync(process.env.INIT_CWD + '/POSTINSTALL-RAN', 'ran\\n')\"" } }
PKG
echo '{ "name": "installcanary-app", "version": "1.0.0", "private": true }' > "$T/app/package.json"
cd "$T/pkg" && $NPM pack --silent >/dev/null 2>&1 || { echo "installcanary: ERROR: '$NPM pack' failed" >&2; exit 3; }
cd "$T/app" || exit 3
v=$($NPM --version 2>/dev/null) || { echo "installcanary: ERROR: '$NPM' didn't run" >&2; exit 3; }
$NPM install --no-audit --no-fund "$T/pkg/installcanary-probe-1.0.0.tgz" >"$T/out" 2>&1 \
  || { echo "installcanary: ERROR: install failed" >&2; tail -5 "$T/out" >&2; exit 3; }
[ -d node_modules/installcanary-probe ] || { echo "installcanary: ERROR: the package didn't install" >&2; exit 3; }

bad=0
echo "installcanary: npm $v"
if [ -f POSTINSTALL-RAN ]; then
  echo "  install scripts    RAN       a package's postinstall ran during install"; bad=1
else
  echo "  install scripts    blocked   the postinstall didn't run"
fi
# npm only honours min-release-age from 11.10.0. npm 10 ignores it silently; early npm 11 warns, then installs anyway.
major=${v%%.*}; rest=${v#*.}; minor=${rest%%.*}
age=$($NPM config get min-release-age 2>/dev/null)
if [ "$major" -lt 11 ] 2>/dev/null || { [ "$major" -eq 11 ] && [ "$minor" -lt 10 ]; }; then
  echo "  min-release-age    ignored   npm $v doesn't support it (needs 11.10.0+), whatever it's set to"; bad=1
else
  case "$age" in
    ""|null|undefined|0) echo "  min-release-age    not set   a release published minutes ago would install"; bad=1 ;;
    *) echo "  min-release-age    $age day(s)  newer releases are refused" ;;
  esac
fi
if [ $bad -eq 1 ]; then
  echo "installcanary: EXPOSED: see README for the two settings"; exit 1
fi
echo "installcanary: HELD"

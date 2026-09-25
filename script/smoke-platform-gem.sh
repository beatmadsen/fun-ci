#!/usr/bin/env bash
# Installs a gem into an empty GEM_HOME and checks what a user would get.
# fun-ci runs, and then, by where the renderer should come from:
#   bundled (default)  a platform gem: the lookup finds the renderer the gem
#                      bundles, not any other, and it draws a frame headless
#   path               the plain gem with a renderer on PATH (cargo install):
#                      the lookup finds that one, and it draws a frame
#   none               the plain gem and no renderer: the lookup says how to
#                      get one
#
#   script/smoke-platform-gem.sh pkg/fun_ci-2.0.0-x86_64-linux.gem
#   script/smoke-platform-gem.sh pkg/fun_ci-2.0.0.gem path
#   script/smoke-platform-gem.sh pkg/fun_ci-2.0.0.gem none
set -euo pipefail

gem_file=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
expect=${2:-bundled}
home=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$home"' EXIT
unset RUBYOPT BUNDLE_GEMFILE BUNDLER_SETUP BUNDLE_BIN_PATH FUN_CI_RENDERER
export GEM_HOME="$home/gems" GEM_PATH="$home/gems"
cd "$home"

fail() { echo "smoke: $*" >&2; exit 1; }

gem install --no-document "$gem_file" > gem-install.log
"$GEM_HOME/bin/fun-ci" --help > /dev/null

lookup='require "fun_ci/console/renderer_lookup"; puts FunCi::Console::RendererLookup.default.path'
if [ "$expect" = none ]; then
  ! ruby -e "$lookup" > lookup.log 2>&1 || fail "the plain gem found a renderer: $(cat lookup.log)"
  grep -q "cargo install fun-ci-renderer" lookup.log || fail "the plain gem did not say how to get a renderer: $(cat lookup.log)"
  echo "smoke: $(basename "$gem_file") runs, and says how to get a renderer"
  exit 0
fi

renderer=$(ruby -e "$lookup")
case "$expect" in
  bundled) [[ "$renderer" == "$GEM_HOME"/* ]] || fail "found $renderer, not the renderer the gem bundles" ;;
  path) [ "$renderer" = "$(command -v fun-ci-renderer)" ] || fail "found $renderer, not the one on PATH" ;;
  *) fail "unknown expectation '$expect'" ;;
esac

printf '%s\n' '{"t":"resize","cols":80,"rows":24}' '{"t":"board","now":1790000000,"runs":[]}' \
  '{"t":"tick","ms":100}' > scenario.jsonl
"$renderer" --headless --cols 80 --rows 24 --scenario scenario.jsonl --out out
test -s out/frames.jsonl || fail "$renderer drew nothing"
echo "smoke: $(basename "$gem_file") runs, and the renderer at $renderer drew $(wc -l < out/frames.jsonl | tr -d ' ') frame(s)"

#!/usr/bin/env bash
# Installs a gem into an empty GEM_HOME and checks what a user would get:
# fun-ci runs; with a platform gem it finds the renderer the gem bundles, not
# any other, and that renderer draws a frame headless; with the plain gem
# (`none`) the lookup says how to get a renderer.
#
#   script/smoke-platform-gem.sh pkg/fun_ci-2.0.0-x86_64-linux.gem
#   script/smoke-platform-gem.sh pkg/fun_ci-2.0.0.gem none
set -euo pipefail

gem_file=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
home=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$home"' EXIT
unset RUBYOPT BUNDLE_GEMFILE BUNDLER_SETUP BUNDLE_BIN_PATH FUN_CI_RENDERER
export GEM_HOME="$home/gems" GEM_PATH="$home/gems"
cd "$home"

gem install --no-document "$gem_file" > gem-install.log
"$GEM_HOME/bin/fun-ci" --help > /dev/null

lookup='require "fun_ci/console/renderer_lookup"; puts FunCi::Console::RendererLookup.default.path'
if [ "${2:-bundled}" = none ]; then
  if ruby -e "$lookup" > lookup.log 2>&1 || ! grep -q "cargo install fun-ci-renderer" lookup.log; then
    echo "smoke: the plain gem should say how to get a renderer; it said:" >&2; cat lookup.log >&2; exit 1
  fi
  echo "smoke: $(basename "$gem_file") runs, and says how to get a renderer"; exit 0
fi
renderer=$(ruby -e "$lookup")
case "$renderer" in
  "$GEM_HOME"/*) ;;
  *) echo "smoke: fun-ci found $renderer, not the renderer its gem bundles" >&2; exit 1 ;;
esac

printf '%s\n' '{"t":"resize","cols":80,"rows":24}' '{"t":"board","now":1790000000,"runs":[]}' \
  '{"t":"tick","ms":100}' > scenario.jsonl
"$renderer" --headless --cols 80 --rows 24 --scenario scenario.jsonl --out out
test -s out/frames.jsonl
echo "smoke: $(basename "$gem_file") runs, and its renderer at $renderer drew $(wc -l < out/frames.jsonl | tr -d ' ') frame(s)"

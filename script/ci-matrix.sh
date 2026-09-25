#!/usr/bin/env bash
# Runs the gate as CI does (frozen lockfile, the lockfile's Bundler) on each
# Ruby in .github/workflows/ci.yml, in a clean Linux container per Ruby.
# Usage: script/ci-matrix.sh [ruby-version...]   (default: the CI matrix)
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$root"
git ls-files -co --exclude-standard | COPYFILE_DISABLE=1 tar --no-xattrs -czf "$work/src.tgz" -T - 2>/dev/null \
  || git ls-files -co --exclude-standard | tar -czf "$work/src.tgz" -T -
cat > "$work/gate.sh" <<'SH'
set -eo pipefail
mkdir /app && cd /app && tar -xzf /src/src.tgz 2>/dev/null
git init -q . && git add -A >/dev/null && git -c user.name=ci -c user.email=ci@example.invalid commit -qm snapshot
gem install bundler -v "$(tail -1 Gemfile.lock | tr -d ' ')" --no-document >/dev/null
bundle config set frozen true >/dev/null
bundle install --quiet
CUCUMBER_OPTS="--format progress" bundle exec rake
SH
versions=("$@")
if [ ${#versions[@]} -eq 0 ]; then
  read -r -a versions <<< "$(ruby -ryaml -e 'puts YAML.safe_load_file(".github/workflows/ci.yml").dig("jobs", "gate", "strategy", "matrix", "ruby").join(" ")')"
fi
status=0
for version in "${versions[@]}"; do
  if docker run --rm -v "$work:/src:ro" "ruby:$version" bash /src/gate.sh > "$work/$version.log" 2>&1; then
    echo "Ruby $version: green ($(grep -E 'runs,' "$work/$version.log"))"
  else
    echo "Ruby $version: RED"; tail -40 "$work/$version.log"; status=1
  fi
done
exit $status

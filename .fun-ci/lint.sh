#!/bin/sh
# Runs beside build.sh, so it reads the source alone: RuboCop, then Clippy on
# the renderer, whose check-mode output in target/ is apart from the build's.
exec bundle exec rake rubocop rust:clippy

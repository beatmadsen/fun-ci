#!/bin/sh
# The gate's lint lanes: RuboCop, then Clippy on the renderer.
exec bundle exec rake rubocop rust:clippy

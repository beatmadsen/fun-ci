#!/bin/sh
# Runs beside lint.sh; then fast.sh and slow.sh run side by side on what it builds.
# The gems, then the renderer with its tests, which the slow stage runs, so
# neither suite compiles anything.
bundle install --quiet && exec cargo build --locked --quiet --all-targets --manifest-path renderer/Cargo.toml

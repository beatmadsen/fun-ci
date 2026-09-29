#!/bin/sh
# The gems, then the renderer, which the contract lane drives in the slow stage.
bundle install --quiet && exec cargo build --locked --quiet --manifest-path renderer/Cargo.toml

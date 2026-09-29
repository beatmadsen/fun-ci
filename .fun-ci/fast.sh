#!/bin/sh
# Runs beside slow.sh, on what build.sh built.
# The subsets of the test lane that start no process, in one process.
exec bundle exec rake fast

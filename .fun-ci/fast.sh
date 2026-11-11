#!/bin/sh
# Runs beside slow.sh, on what build.sh built.
# The unit and acceptance tests, which start no process and check what
# fun-ci does, in one process; the checks on the repository run in slow.sh.
exec bundle exec rake fast

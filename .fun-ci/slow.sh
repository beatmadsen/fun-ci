#!/bin/sh
# The rest of the gate, then the mutants in this commit's own lines.
exec bundle exec rake integration rust:test contract:binary "mutation:changed[HEAD~1]"

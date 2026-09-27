#!/bin/sh
# A project's own extractor, as docs/architecture.md describes one: it reads the context on
# stdin and prints the evidence it found as JSON.
stage=$(grep -o '"stage": *"[a-z]*"' | sed 's/.*"\([a-z]*\)"$/\1/')
printf '{"schema": 1, "facts": [{"name": "stage", "value": "%s"}],\n' "$stage"
printf ' "excerpts": [{"title": "From the shell", "location": "sample", "lines": ["one", "two"]}]}\n'

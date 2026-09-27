Presets: config entries fun-ci ships for popular tools, one file each, named
for the preset, in the shape a project would write an entry (`use:` and the
built-in's options), with when it applies: `markers`, files any of which the
worktree must have (a path, or `{ path:, contains: }`), and `signature`, a
pattern only the tool prints, matched within one line. Each is pinned by the
recorded output of a real failing run in `test/fixtures/evidence/<name>/`, and
none ships without one (`test/policy/test_evidence_fixtures.rb`).

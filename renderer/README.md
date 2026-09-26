# fun-ci-renderer

The terminal renderer of [fun-ci](https://github.com/beatmadsen/fun-ci)'s
console. The `fun-ci` gem decides what is true about your pipelines; this
program draws it: the board, the animations, the keys you press.

You rarely need it on its own. The `fun-ci` gem for Linux (x86_64, aarch64,
musl) and macOS (arm64, x86_64) bundles it. On any other system, install the
plain gem and then the renderer:

```sh
cargo install fun-ci-renderer
```

`fun-ci console` looks for the renderer in `FUN_CI_RENDERER` first, then in
the gem, then on your `PATH`.

It speaks JSON Lines with the gem over stdin and stdout
([protocol](https://github.com/beatmadsen/fun-ci/blob/main/docs/renderer-protocol.md))
and draws on `/dev/tty`. `--headless` replays a scenario into PNG frames, a
contact sheet, an asciicast and measurements instead of drawing on a terminal.

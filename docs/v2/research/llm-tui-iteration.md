# AI-driven design and iteration of advanced terminal interfaces

**The most credible approach is a coding agent connected to a controllable terminal, rendered images, and repeatable tests.** Concrete implementations exist, including a Claude Code plugin specifically for tuning terminal animations. The largest weakness is motion evaluation: a workflow that produces a GIF does not necessarily let the model watch it.

This report draws on primary project documentation, agent instructions and model-provider documentation. The implementations below are documented, but I did not run them or independently measure their effectiveness.

## How others have built the pipeline

### 1. Encode the design process in skills, then render and critique

Zvi Baratz's [terminal-animations](https://github.com/ZviBaratz/terminal-animations) is the closest match to the full request. It combines a Claude Code authoring skill, animation references, preview scripts, tests and an optional visual-tuning agent. Its examples include half-block plasma, a braille-rendered 3D torus, layered scenery and stateful animation.

The [tuner's instructions](https://github.com/ZviBaratz/terminal-animations/blob/main/agents/tuner.md) prescribe an explicit loop:

1. Identify adjustable parameters such as speed, brightness, frequency and sharpness.
2. Render frames and check dimensions, glyphs and whether consecutive frames change.
3. Measure luminance distribution, dark space and hue spread.
4. Render a sweep of candidate values, changing one parameter at a time.
5. Inspect the coloured results against a written visual brief, then revise.

This uses visual intelligence for composition and preference, while numerical measurements help diagnose *why* something looks wrong. The tuner must also recognise when parameter changes cannot solve a missing visual mechanism, such as absent depth or lighting.

The integration is relatively small: Claude Code skills, shell tools, an ANSI-to-PNG renderer and image reading. Recording uses Python and FFmpeg, with an alternative VHS path. Its companion [charm-tui](https://github.com/ZviBaratz/charm-tui) plugin adds real-application interaction, resizing and visual review to Go TUI verification.

**Caveat:** instructions to inspect an animation establish the intended workflow, not proof that the model receives moving images. That distinction becomes decisive below.

### 2. Give the agent a terminal it can operate and observe

AWS's [AgentCore CLI TUI harness](https://github.com/aws/agentcore-cli/blob/main/docs/tui-harness.md) is a concrete MCP implementation. It exposes launch, keypresses, screen reading, readiness waits, screenshots and cleanup. Its documentation includes a complete wizard walkthrough captured from a real session.

An instructive integration detail: AWS recommends a local HTTP MCP server because its Claude Code sandbox prevented `node-pty` from spawning processes through the stdio setup. This is an environment-specific constraint, not a general requirement to use HTTP.

[MICROSOFT's `tui-test`](https://github.com/microsoft/tui-test) provides a broader reusable alternative: terminal control, text and style matching, resizing, PNG/SVG capture, recordings and failure traces. It includes agent instructions and CLI/library interfaces, so **MCP is optional**. Its current documentation describes a beta rewrite, which makes release pinning advisable.

[Tuistory](https://github.com/remorses/tuistory) takes a similar CLI-first approach. Its README identifies Termcast as a consumer for agent-assisted conversion of Raycast extensions into TUIs. Termcast's [agent instructions](https://github.com/remorses/termcast/blob/main/AGENTS.md) explicitly describe changing code, running tests, reading snapshots and repeating. That demonstrates a concrete iteration method, though text snapshots alone do not establish visual evaluation.

### 3. Supply visual references before asking for design

[terminal-love-mcp](https://github.com/jpoindexter/terminal-love-mcp), built for the Vanta agent, searches Terminal Trove and returns screenshots as actual MCP image blocks. The agent can inspect existing layouts rather than work from descriptions alone.

This is a useful design-stage integration: collect relevant examples, inspect their information hierarchy and interaction patterns, then implement against a specific brief. It is a reference-gathering component, not a complete evaluation system.

### 4. Generate bounded animation data instead of arbitrary code

[claude-code-scenes](https://github.com/rezathepure/claude-code-scenes) demonstrates another approach. Natural-language requests produce declarative themes containing particle fields, sprites and restricted shader expressions. Users preview the animation and text colours, request changes, undo refinements and keep the result.

The transferable idea is **a fixed renderer consuming model-generated scene data**, with model calls outside the animation loop. Refinements return deltas so unrelated choices remain unchanged.

Its documented critic is the human watching the preview. It is also an unofficial Claude Code reproduction/fork, not Anthropic's distribution.

## How to employ visual intelligence correctly

Use different observations for different questions:

| Observation | Useful for |
|---|---|
| Text and styled terminal cells | Exact labels, selection, layout bounds and state transitions |
| Raster screenshots | Hierarchy, spacing, contrast, density and comparisons with references |
| Timestamped frame sequences or video | Motion direction, transitions, trails and visual continuity |
| Timing and rendering measurements | Frame stalls, input responsiveness and output cost |

**The GIF trap is real.** [Anthropic's vision documentation](https://platform.claude.com/docs/en/build-with-claude/vision#supported-formats) explicitly says animations are unsupported and only the first frame is used. Consequently, the animation plugin's instruction to “judge the GIF” is insufficient if that GIF reaches Claude as one ordinary image.

A reliable pipeline must extract ordered PNG frames, use a video-capable model integration, or retain human playback review. [Gemini's video API](https://ai.google.dev/gemini-api/docs/video-understanding) supports video and configurable sampling, but its documented default static sampling is one frame per second. That can miss brief transitions and flicker. Even video-based critique should not replace timing measurements.

Likewise, confirm that a “screenshot” tool actually delivers pixels. AWS's default screenshot is text. An SVG saved to disk also needs rendering or suitable image handling before it becomes visual model input.

## Recommended implementation

I would combine these approaches into a reproducible loop:

1. **Specify the target.** Define terminal capabilities, supported sizes, keyboard behaviour, visual references and the intended motion. Explicitly distinguish decorative animation from feedback that communicates application state.
2. **Build deterministic scenarios.** Fix data, dimensions, fonts, theme and randomness. Make animation time controllable. Capture loading, empty, error, selection and resize states, not just the opening screen.
3. **Drive and capture the real application.** Use `tui-test`, Tuistory or an existing project-specific driver. Wait for meaningful state markers; continuously animated screens may never become idle.
4. **Compare rendered candidates.** Give the visual critic the brief, reference images and labelled alternatives. Require observations tied to image regions or timestamps, followed by specific changes. Keep visual preference separate from correctness.
5. **Preserve accepted behaviour.** Retain interaction tests, geometry checks, transition/loop checks and reviewed visual baselines. [Textual's Pilot and snapshot testing](https://textual.textualize.io/guide/testing/) provide a framework-native option; [VHS](https://github.com/charmbracelet/vhs) provides scripted recordings and PNG frame sequences.

For advanced animation, I would start with the Baratz authoring/tuning approach and add explicit frame extraction. For application interaction, I would evaluate `tui-test` before building a custom MCP server. Finally, inspect the result in the intended terminal emulator: reconstructed images cannot establish that its font rendering and live repaint behaviour are correct.

The reviewed sources support this architecture. They do **not** establish a best LLM or demonstrate that autonomous visual judgment reliably replaces human approval of sophisticated animation.

*Research and sources saved in the knowledge base as `Egb4nGZ`.*

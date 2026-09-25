# frozen_string_literal: true

module AnimationRendererTestHelpers
  FAKE_ANIMATION_DATA = {
    name: "Fake", fps: 8,
    frames: [%w[line-one line-two], %w[line-one line-two]]
  }.freeze

  FAKE_IDLE_DATA = {
    name: "Idle", fps: 4,
    frames: [14.times.map { |i| "idle-#{i}" }, 14.times.map { |i| "idle-#{i}" }]
  }.freeze

  FAKE_RUNNING_DATA = {
    name: "Running", fps: 4,
    frames: [14.times.map { |i| "running-#{i}" }, 14.times.map { |i| "running-#{i}" }]
  }.freeze

  FakeAnimationLibrary = Module.new do
    extend self

    define_method(:random_failure) { AnimationRendererTestHelpers::FAKE_ANIMATION_DATA }
    define_method(:random_success) { AnimationRendererTestHelpers::FAKE_ANIMATION_DATA }
    define_method(:idle) { AnimationRendererTestHelpers::FAKE_IDLE_DATA }
    define_method(:running) { AnimationRendererTestHelpers::FAKE_RUNNING_DATA }
  end

  def make_renderer_and_screen(width: 80, animation_library: FakeAnimationLibrary)
    output = StringIO.new
    renderer = FunCi::Tui::AnimationRenderer.new(animation_library: animation_library)
    screen = FunCi::Tui::Screen.new(output: output, width: width)
    [renderer, screen, output]
  end

  def make_run(id, status, **stage_overrides)
    stages = %w[lint build fast slow].map do |name|
      { stage: name, status: stage_overrides.fetch(name.to_sym, "pending"), duration: 0.1 }
    end
    { id: id, commit_hash: "a3f7c01", branch: "main", status: status, stages: stages }
  end
end

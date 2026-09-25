# The build loop runs agents with --dangerously-skip-permissions, so it runs
# here: the host repo is mounted read-only, the loop works on its own clone,
# and results leave only as a git bundle in /out. Built by ralph/docker/run.sh.
FROM ruby:4.0-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      git curl ca-certificates build-essential pkg-config libsqlite3-dev procps \
    && rm -rf /var/lib/apt/lists/*

# Claude Code refuses to skip permissions as root.
RUN useradd --create-home --shell /bin/bash ralph && mkdir /work && chown ralph /work
USER ralph
WORKDIR /home/ralph
ENV PATH=/home/ralph/.local/bin:/home/ralph/.cargo/bin:$PATH

RUN curl -fsSL https://claude.ai/install.sh | bash
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && uv tool install ralphify==0.3.0
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --component clippy

# Warm the gem cache; each clone still runs bundle install against its own lockfile.
COPY --chown=ralph Gemfile Gemfile.lock fun_ci.gemspec /home/ralph/gems/
COPY --chown=ralph lib/fun_ci/version.rb /home/ralph/gems/lib/fun_ci/version.rb
RUN cd /home/ralph/gems && bundle install --quiet

COPY --chown=ralph ralph/docker/entrypoint.sh /home/ralph/entrypoint.sh
ENTRYPOINT ["/home/ralph/entrypoint.sh"]

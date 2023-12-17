FROM fedora:39

ENV MIX_ENV="prod"

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# set runner ENV
ENV MIX_ENV="prod"

USER nobody
# Only copy the final release from the build stage
# First run: MIX_ENV=prod mix release
ADD --chown=nobody:root ./_build/${MIX_ENV}/rel/phoenix_iot ./

cmd ["/app/bin/server"]
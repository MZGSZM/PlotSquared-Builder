# Builds PlotSquared from source and exports the Bukkit plugin jar.
# Run it through build.sh, which passes the build args and the output folder.

# Java 21 is what PlotSquared's Gradle toolchain asks for. This is a
# requirement, not a pin: the image still tracks the newest 21 release.
FROM eclipse-temurin:21-jdk AS build

RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

ARG P2_REPO=https://github.com/IntellectualSites/PlotSquared.git
ARG P2_REF=latest
# build.sh sets this to the current time so "latest" and "dev" are
# re-resolved on every run instead of being served from a stale layer.
ARG CACHE_BUST=0

COPY scripts/checkout.sh /usr/local/bin/checkout.sh
RUN printf 'cache bust: %s\n' "$CACHE_BUST" \
    && bash /usr/local/bin/checkout.sh "$P2_REPO" "$P2_REF" /build/src

WORKDIR /build/src

# The cache mount keeps Gradle's dependency and wrapper downloads between
# runs, so a rebuild does not re-download everything.
RUN --mount=type=cache,target=/root/.gradle \
    bash ./gradlew clean build --no-daemon

# Keep only the plugin jar, not sources or javadoc jars.
RUN mkdir /out \
    && find Bukkit/build/libs -name '*.jar' ! -name '*-sources.jar' ! -name '*-javadoc.jar' -exec cp -- {} /out/ \; \
    && cp -- BUILD_INFO /out/BUILD_INFO \
    && ls /out/*.jar >/dev/null

FROM scratch AS export
COPY --from=build /out/ /

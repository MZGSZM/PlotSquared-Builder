# PlotSquared Builder

Builds the [PlotSquared](https://github.com/IntellectualSites/PlotSquared) Minecraft plugin from source inside a container, for server admins who want a jar they compiled themselves from a release tag, a dev branch, or a specific commit.

This is an unofficial helper. It is not made by or affiliated with IntellectualSites. It ships no PlotSquared code or binaries: it clones upstream at build time and compiles it on your machine.

## Prerequisites

- Docker 23 or newer (BuildKit is on by default from there), or Podman 4 or newer
- bash 4.4 or newer
- Network access to GitHub, Docker Hub, services.gradle.org and Maven repositories
- Around 2 GB of free disk for the image and Gradle's cache

You do not need Java or Gradle on the host. The container brings Java 21 and the project's own Gradle wrapper.

## Usage

1. Clone this repo: `git clone https://github.com/MZGSZM/PlotSquared-Builder.git`
2. Go into it: `cd PlotSquared-Builder`
3. Build the newest release: `bash build.sh`
4. Grab the jar from `output/`, along with `output/BUILD_INFO`, which records the exact commit and version that was built.

I call it with `bash build.sh` rather than `./build.sh` because uploading through GitHub's web UI drops the executable bit. If you cloned with git, `./build.sh` works too.

### Picking a version

- `bash build.sh -v 7.6.0` builds a specific release tag
- `bash build.sh -v latest` builds the newest `x.y.z` tag (this is the default)
- `bash build.sh -v dev` builds the tip of the default branch, which is a `-SNAPSHOT`
- `bash build.sh -v main` or `-v <commit>` builds a branch or commit
- `bash build.sh -o ~/server/plugins` writes somewhere other than `./output`
- `bash build.sh -r https://github.com/<fork>/PlotSquared.git` builds a fork

Every run re-resolves `latest` and `dev`, so you never get a stale version from Docker's layer cache. Gradle's downloads are cached between runs, so rebuilds are much faster than the first one.

## Why a 7.6.0 checkout used to give you 7.6.1-SNAPSHOT

Upstream's `7.6.0` tag points at the wrong commit. Their release went out as two commits four minutes apart on 2026-08-16:

- `90fc81fd` "Release 7.6.0", which sets `version = "7.6.0"` in `build.gradle.kts`
- `18a4a412` "Back to snapshot for development", which bumps it to `7.6.1-SNAPSHOT`

The tag landed on the second one. The only difference between the two is that version line, so the code you built was 7.6.0, just labeled wrong. 7.5.11 was tagged on its release commit, which is why that one came out fine.

`scripts/checkout.sh` now catches this. When a release tag's `build.gradle.kts` does not match the tag name, it walks back to the matching "Release x.y.z" commit and builds that. If it can't find one, it stops instead of handing you a mislabeled jar. `build.sh` also fails if a release build still comes out as `-SNAPSHOT`; pass `-s` if you want to keep it anyway.

## What the build does

1. Starts from `eclipse-temurin:21-jdk`, since Java 21 is what PlotSquared's Gradle toolchain requires.
2. Clones upstream and checks out the ref you asked for, with the tag correction above.
3. Runs `./gradlew clean build`, which includes upstream's tests.
4. Exports only the Bukkit plugin jar and `BUILD_INFO` to your output folder.

The export uses `--output type=local`, so no container is left running and every file in `output/` is owned by you, not root.

## On distributing jars

I don't publish built jars from this repo. For what it's worth, PlotSquared is GPL-3.0, which does allow redistributing builds as long as you pass along the license and the corresponding source. Upstream also attaches official jars to its GitHub releases. So this tool is mostly useful for dev builds, forks, and checking that a jar matches its source. I'm not a lawyer; read the license if you plan to hand jars to others.

The GitHub Actions workflow in `.github/workflows/verify-build.yml` builds the latest release on every push and weekly. It uploads nothing. It exists only to tell you when upstream changes break the builder.

## Troubleshooting

- **`failed to solve` or `--mount` errors**: your Docker is older than 23 or BuildKit is off. Update Docker, or run with `DOCKER_BUILDKIT=1`.
- **Gradle fails with a Java version error**: upstream raised its toolchain. Change `eclipse-temurin:21-jdk` in the `Dockerfile` to the new version.
- **Build is slow the first time**: expected, it downloads Gradle and every dependency. Later runs reuse the cache.
- **Want a completely clean slate**: `docker builder prune` clears the Gradle cache mount along with old layers.

Now PlotSquared is built from the exact source you picked, the jar is labeled with the version it really is, and it's sitting in `output/` ready to drop into `plugins/`. Tinker with the Dockerfile as you see fit if you need other modules or flags.

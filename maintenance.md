# Maintenance

Run through this every couple of months, or whenever the Actions badge goes red. It takes about 15 minutes if nothing is broken.

## 1. Check the scheduled build

1. Open the repo's Actions tab and look at the last few "Verify build" runs.
2. If they're green, upstream's latest release still builds. Skip to step 3.
3. If one failed, open the log and find which step broke. The checkout step prints `checkout.sh:` lines, the Gradle step prints Gradle errors.

## 2. Build locally

1. `bash build.sh -v latest`
2. `cat output/BUILD_INFO` and confirm `version=` matches the newest tag on [PlotSquared's tags page](https://github.com/IntellectualSites/PlotSquared/tags).
3. `bash build.sh -v dev` to confirm the dev branch still builds, since that's the early warning for the next release.

## 3. Things that tend to change upstream

- **Java version.** Check `build.gradle.kts` upstream for `JavaLanguageVersion.of(...)` in the `toolchain` block. If it's no longer 21, change `FROM eclipse-temurin:21-jdk` in the `Dockerfile` to match.
- **Version line format.** `checkout.sh` reads `version = "x.y.z"` from `build.gradle.kts`. If upstream moves the version to `gradle.properties` or changes the format, `read_version` in `scripts/checkout.sh` needs updating. You'll know because every tag will report an empty version.
- **Release commit message.** The tag correction searches for a commit titled `Release x.y.z`. If upstream changes that wording, update the `--grep` in `checkout.sh`.
- **Jar location.** The Dockerfile collects jars from `Bukkit/build/libs`. If upstream renames the module folder, the build fails at the `ls /out/*.jar` step. Update the path.
- **Tag naming.** `latest` only matches tags shaped like `7.6.0`. If upstream starts using `v7.6.0`, change the `grep -E` pattern in `checkout.sh`.

## 4. Things that change on this side

- **actions/checkout.** The workflow uses `actions/checkout@v7`. When a new major comes out, bump it.
- **shellcheck.** Run `shellcheck build.sh scripts/checkout.sh` after any edit. It should print nothing.

## 5. Log it

Add an entry to `changes.md` for anything you changed, even a one-line Dockerfile bump.

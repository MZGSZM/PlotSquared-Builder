#!/usr/bin/env bash
# Builds PlotSquared from source in a container and drops the jar in ./output.
#
# Usage: build.sh [-v version] [-o output-dir] [-r repo-url] [-s]
#   -v  latest (default), dev, a release tag like 7.6.0, a branch, or a commit
#   -o  output folder (default: ./output)
#   -r  git repo to build from (default: upstream PlotSquared)
#   -s  allow a -SNAPSHOT jar for a release tag instead of failing

set -euo pipefail
export LC_ALL=C

die() {
    printf 'build.sh: %s\n' "$1" >&2
    exit 1
}

usage() {
    printf 'Usage: %s [-v version] [-o output-dir] [-r repo-url] [-s]\n' "$0"
}

version=latest
outdir=./output
repo=https://github.com/IntellectualSites/PlotSquared.git
allow_snapshot=0

while getopts 'v:o:r:sh' opt; do
    case "$opt" in
        v) version=$OPTARG ;;
        o) outdir=$OPTARG ;;
        r) repo=$OPTARG ;;
        s) allow_snapshot=1 ;;
        h) usage; exit 0 ;;
        *) usage >&2; exit 1 ;;
    esac
done

# Docker first, Podman as a fallback. Both understand --output.
engine=""
if command -v docker >/dev/null 2>&1; then
    engine=docker
elif command -v podman >/dev/null 2>&1; then
    engine=podman
fi

missing=""
[ -n "$engine" ] || missing="$missing docker-or-podman"
for cmd in date dirname mkdir find grep sed; do
    command -v "$cmd" >/dev/null 2>&1 || missing="$missing $cmd"
done
[ -z "$missing" ] || die "missing required commands:$missing"

script_dir=$(cd "$(dirname -- "$0")" && pwd)
cd "$script_dir" || exit 1

# Make the folder ourselves. --output writes files as the calling user, so
# nothing ends up owned by root.
mkdir -p -- "$outdir"
find "$outdir" -maxdepth 1 \( -name '*.jar' -o -name BUILD_INFO \) -exec rm -f -- {} \;

printf 'Building PlotSquared (%s) with %s...\n' "$version" "$engine"

if [ "$engine" = docker ]; then
    export DOCKER_BUILDKIT=1
fi

"$engine" build \
    --target export \
    --output "type=local,dest=$outdir" \
    --build-arg "P2_REPO=$repo" \
    --build-arg "P2_REF=$version" \
    --build-arg "CACHE_BUST=$(date +%s)" \
    .

[ -f "$outdir/BUILD_INFO" ] || die "build finished but BUILD_INFO is missing from $outdir"
built=$(sed -n 's/^version=//p' "$outdir/BUILD_INFO")

case "$version" in
    latest | [0-9]*.[0-9]*.[0-9]*)
        case "$built" in
            *-SNAPSHOT)
                if [ "$allow_snapshot" -eq 1 ]; then
                    printf 'build.sh: warning: release build came out as %s\n' "$built" >&2
                else
                    die "asked for $version but got $built (use -s to keep it anyway)"
                fi
                ;;
        esac
        ;;
esac

printf '\nDone. PlotSquared %s is in %s:\n' "$built" "$outdir"
find "$outdir" -maxdepth 1 -name '*.jar' -print

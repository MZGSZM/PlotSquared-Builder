#!/usr/bin/env bash
# Runs inside the build container. Clones PlotSquared and checks out the
# requested ref, correcting for release tags that point at the
# "Back to snapshot for development" commit instead of the release commit.
#
# Usage: checkout.sh <repo-url> <ref> <dest-dir>
#   ref: "latest" (newest x.y.z tag), "dev" (default branch), a tag, a branch, or a commit

set -euo pipefail
export LC_ALL=C

die() {
    printf 'checkout.sh: %s\n' "$1" >&2
    exit 1
}

missing=""
for cmd in git sed grep head; do
    command -v "$cmd" >/dev/null 2>&1 || missing="$missing $cmd"
done
[ -z "$missing" ] || die "missing required commands:$missing"

[ "$#" -eq 3 ] || die "usage: checkout.sh <repo-url> <ref> <dest-dir>"
repo=$1
ref=$2
dest=$3

# blob:none keeps the clone small but keeps full history, which we need to
# walk back from a misplaced tag to its release commit.
git clone --quiet --filter=blob:none -- "$repo" "$dest"
cd "$dest" || exit 1

read_version() {
    # Prints the version string from build.gradle.kts at the given commit.
    git show "$1:build.gradle.kts" | sed -n 's/^version = "\(.*\)"$/\1/p' | head -n 1
}

is_tag=0
case "$ref" in
    latest)
        ref=$(git tag --sort=-v:refname | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1)
        [ -n "$ref" ] || die "no x.y.z release tags found in $repo"
        is_tag=1
        ;;
    dev)
        ref=$(git symbolic-ref --short refs/remotes/origin/HEAD)
        ;;
    *)
        if git rev-parse --quiet --verify "refs/tags/$ref" >/dev/null; then
            is_tag=1
        elif git rev-parse --quiet --verify "refs/remotes/origin/$ref" >/dev/null; then
            ref="origin/$ref"
        elif ! git rev-parse --quiet --verify "$ref^{commit}" >/dev/null; then
            die "'$ref' is not a tag, branch, or commit in $repo"
        fi
        ;;
esac

commit=$(git rev-parse "$ref^{commit}")
version=$(read_version "$commit")

if [ "$is_tag" -eq 1 ] && [ "$version" != "$ref" ]; then
    printf 'checkout.sh: tag %s declares version "%s", looking for its release commit\n' "$ref" "$version" >&2
    release=$(git log -n 1 --format=%H --fixed-strings --grep="Release $ref" "$commit")
    if [ -n "$release" ] && [ "$(read_version "$release")" = "$ref" ]; then
        printf 'checkout.sh: using release commit %s instead of tagged commit %s\n' "$release" "$commit" >&2
        commit=$release
        version=$ref
    else
        die "tag $ref builds as $version and no matching 'Release $ref' commit was found"
    fi
fi

git checkout --quiet --detach "$commit"

printf 'requested=%s\ncommit=%s\nversion=%s\nrepo=%s\n' "$2" "$commit" "$version" "$repo" >"$dest/BUILD_INFO"
printf 'checkout.sh: building PlotSquared %s at %s\n' "$version" "$commit"

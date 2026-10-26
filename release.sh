#!/bin/sh
# Publishes a Splitter release under your own GitHub account:
#
#   ./release.sh v0.2.0
#
# Push the tag first and wait for the release workflow
# (.github/workflows/release.yml). It builds and checksums the package but
# doesn't publish it, so that the release is made by your account, not by
# GitHub's bot. This takes the workflow's files for the tag, checks them
# against its SHA256SUMS.txt and publishes them as a pre-release (the
# build is test-signed; see README.md, "Signing").
#
# Needs: gh (GitHub's command line, logged in), sha256sum.
set -eu
REPO=LudaLunizz/Splitter
fail() { echo "release.sh: $*" >&2; exit 1; }

TAG=${1:-}
case "$TAG" in
  v[0-9]*) ;;
  *) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
command -v gh >/dev/null || fail "needs gh (GitHub's command line)"
command -v sha256sum >/dev/null || fail "needs sha256sum"
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  fail "$TAG is released already"
fi

# the workflow's files for the tag (the newest, if it ran more than once)
NAME="splitter-$TAG"
RUN=$(gh api "repos/$REPO/actions/artifacts?name=$NAME" \
  --jq '[.artifacts[] | select(.expired | not)] | sort_by(.created_at) | last | .workflow_run.id // empty')
[ -n "$RUN" ] || fail "no release files for $TAG: has the release workflow finished for it?"
# Only from a finished, successful run of release.yml in this repository:
# a pull request's run could leave files of the same name.
FROM=$(gh api "repos/$REPO/actions/runs/$RUN" --jq '"\(.path) \(.event) \(.conclusion) \(.head_repository.full_name)"')
case "$FROM" in
  ".github/workflows/release.yml push success $REPO" | ".github/workflows/release.yml workflow_dispatch success $REPO") ;;
  *) fail "$NAME is from run $RUN ($FROM), not a successful run of release.yml" ;;
esac

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
gh run download "$RUN" --repo "$REPO" --name "$NAME" --dir "$WORK/files"
cd "$WORK/files"
[ -s SHA256SUMS.txt ] || fail "run $RUN left no SHA256SUMS.txt"
sha256sum --check --quiet --strict SHA256SUMS.txt || fail "run $RUN's files don't match its SHA256SUMS.txt"
# exactly the files the checksums are for
listed=$(awk '{ sub(/^\*/, "", $2); print $2 }' SHA256SUMS.txt | sort)
present=$(ls | grep -vx SHA256SUMS.txt | sort || true)
[ "$listed" = "$present" ] || fail "run $RUN's files are not the ones its SHA256SUMS.txt lists"
echo "files:"
sed 's/^/  /' SHA256SUMS.txt

gh release create "$TAG" --repo "$REPO" ./* \
  --title "Splitter ${TAG#v} (test-signed)" \
  --notes "BananaSplit's own virtual cables, one for each of its eleven channels (Splitter 1 to 6 for the strips, Splitter A1 to B2 for the buses). This build is test-signed: it installs only on a PC in test-signing mode. See README.txt in the zip." \
  --prerelease \
  --verify-tag
echo "published $TAG as a pre-release under your GitHub account"

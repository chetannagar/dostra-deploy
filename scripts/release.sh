#!/usr/bin/env bash

# Release helper for the Dostra deploy repo.
#
# Each release lives in releases/v<version>/ and records:
# - VERSION          the deploy version (SemVer, no "v" prefix)
# - components.json  exact api/web commits plus PHP, Node, Postgres and Nginx versions
# - CHANGELOG.md     human-readable notes for that release
#
# The deploy version is the single version of the whole stack. Bump it whenever
# a submodule pointer moves, or compose, Nginx or the scripts change.
#
# Usage:
#   ./scripts/release.sh prepare <version>   create/refresh releases/v<version>/
#   ./scripts/release.sh tag <version>       tag the commit that contains the release
#   ./scripts/release.sh show [<version>]    print a release's components (default: latest)
#
# Typical flow:
#   1. Commit and push inside dostra-api and dostra-web, then commit the new
#      submodule pointers here.
#   2. ./scripts/release.sh prepare 1.1.0
#   3. Edit releases/v1.1.0/CHANGELOG.md, commit the releases/ folder.
#   4. ./scripts/release.sh tag 1.1.0 && git push --follow-tags
#
# Requires: git, jq.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RELEASES_DIR="releases"
SUBMODULES=(dostra-api dostra-web)

# ── Helpers ────────────────────────────────────────────────────────────────────

die() {
  echo "ERROR: $*" >&2
  exit 1
}

usage() {
  sed -n '3,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-1}"
}

require_tools() {
  command -v jq >/dev/null 2>&1 || die "jq is required (brew install jq / apt install jq)."
}

validate_version() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] \
    || die "'$1' is not a SemVer version (expected e.g. 1.2.3, without a leading 'v')."
}

# True when the file is missing or has no content.
is_blank() {
  [ ! -s "$1" ] || [ -z "$(tr -d '[:space:]' <"$1")" ]
}

# All released versions, oldest first.
list_versions() {
  [ -d "$RELEASES_DIR" ] || return 0
  find "$RELEASES_DIR" -mindepth 1 -maxdepth 1 -type d -name 'v*' -exec basename {} \; \
    | sed 's/^v//' | sort -V
}

# The newest version older than $1 that already has a filled-in components.json.
previous_version() {
  local current="$1" v prev=""
  for v in $(list_versions); do
    [ "$v" = "$current" ] && break
    is_blank "$RELEASES_DIR/v$v/components.json" || prev="$v"
  done
  echo "$prev"
}

# Value of a "FROM image:tag" or "ARG NAME=value" style setting, for components.json.
php_version() {
  sed -n 's/^ARG PHP_VERSION=\(.*\)$/\1/p' dostra-api/Dockerfile.prod | head -n 1
}

node_image() {
  sed -n 's/^FROM \(node:[^ ]*\).*/\1/p' dostra-web/Dockerfile.prod | head -n 1
}

compose_image() {
  sed -n "s/^[[:space:]]*image: \($1:[^ ]*\).*/\1/p" docker-compose.prod.yml | head -n 1
}

# Nginx is built from nginx/Dockerfile (it adds Filament's assets to the base image).
nginx_image() {
  sed -n 's/^FROM \(nginx:[^ ]*\).*/\1/p' nginx/Dockerfile | head -n 1
}

# ── Checks ─────────────────────────────────────────────────────────────────────

check_submodules() {
  local sub
  for sub in "${SUBMODULES[@]}"; do
    [ -e "$sub/.git" ] || die "$sub is not checked out (run: git submodule update --init)."

    [ -z "$(git -C "$sub" status --porcelain)" ] \
      || die "$sub has uncommitted changes. Commit them inside the submodule first."

    # The deploy repo must point at a commit that other machines can fetch.
    git -C "$sub" fetch --quiet origin 2>/dev/null || echo "WARNING: could not fetch $sub; push check may be stale." >&2
    [ -n "$(git -C "$sub" branch --remotes --contains HEAD)" ] \
      || die "$sub HEAD is not pushed to any remote branch. Push it first."
  done

  git diff --quiet HEAD -- "${SUBMODULES[@]}" \
    || die "Submodule pointers have uncommitted changes. Commit them in this repo first."
}

# ── Generated content ──────────────────────────────────────────────────────────

write_components() {
  local version="$1" file="$2" sub
  local api_sha web_sha
  api_sha="$(git -C dostra-api rev-parse HEAD)"
  web_sha="$(git -C dostra-web rev-parse HEAD)"

  jq -n \
    --arg version "$version" \
    --arg released "$(date +%F)" \
    --arg api_sha "$api_sha" \
    --arg api_branch "$(git -C dostra-api rev-parse --abbrev-ref HEAD)" \
    --arg api_describe "$(git -C dostra-api describe --tags --always)" \
    --arg api_subject "$(git -C dostra-api log -1 --format=%s)" \
    --arg web_sha "$web_sha" \
    --arg web_branch "$(git -C dostra-web rev-parse --abbrev-ref HEAD)" \
    --arg web_describe "$(git -C dostra-web describe --tags --always)" \
    --arg web_subject "$(git -C dostra-web log -1 --format=%s)" \
    --arg php "$(php_version)" \
    --arg node "$(node_image)" \
    --arg postgres "$(compose_image postgres)" \
    --arg nginx "$(nginx_image)" \
    '{
      version: $version,
      released: $released,
      api: {commit: $api_sha, branch: $api_branch, describe: $api_describe, subject: $api_subject},
      web: {commit: $web_sha, branch: $web_branch, describe: $web_describe, subject: $web_subject},
      runtime: {php: $php, node: $node, postgres: $postgres, nginx: $nginx}
    }' >"$file"
}

# Commit subjects between two refs of a repo, as markdown bullets.
commit_list() {
  local repo="$1" range="$2" out
  out="$(git -C "$repo" log --no-merges --format='- %s (%h)' "$range" 2>/dev/null || true)"
  echo "${out:-- No changes.}"
}

write_changelog_scaffold() {
  local version="$1" prev="$2" file="$3"
  local deploy_range api_range web_range

  if [ -n "$prev" ]; then
    local prev_json="$RELEASES_DIR/v$prev/components.json"
    deploy_range="v$prev..HEAD"
    git rev-parse --quiet --verify "refs/tags/v$prev" >/dev/null || deploy_range="HEAD~20..HEAD"
    api_range="$(jq -r .api.commit "$prev_json")..HEAD"
    web_range="$(jq -r .web.commit "$prev_json")..HEAD"
  fi

  {
    echo "# v$version — $(date +%F)"
    echo
    if [ -z "$prev" ]; then
      echo "Initial release. Describe what this release contains."
      echo
    else
      echo "Changes since v$prev. Rewrite the lists below into readable notes."
      echo
      echo "## Deploy"
      commit_list . "$deploy_range"
      echo
      echo "## API (dostra-api)"
      commit_list dostra-api "$api_range"
      echo
      echo "## Web (dostra-web)"
      commit_list dostra-web "$web_range"
      echo
    fi
  } >"$file"
}

# ── Commands ───────────────────────────────────────────────────────────────────

cmd_prepare() {
  local version="${1:-}"
  [ -n "$version" ] || usage
  validate_version "$version"
  check_submodules

  local dir="$RELEASES_DIR/v$version"
  mkdir -p "$dir"

  if ! is_blank "$dir/components.json"; then
    die "$dir/components.json already exists. Release v$version looks final; bump the version or delete the folder to redo it."
  fi

  local prev
  prev="$(previous_version "$version")"

  echo "$version" >"$dir/VERSION"
  write_components "$version" "$dir/components.json"

  # Never overwrite notes someone already wrote.
  if is_blank "$dir/CHANGELOG.md"; then
    write_changelog_scaffold "$version" "$prev" "$dir/CHANGELOG.md"
    echo "Scaffolded $dir/CHANGELOG.md — edit it before committing."
  else
    echo "Kept existing $dir/CHANGELOG.md."
  fi

  echo "Prepared $dir:"
  jq -r '"  api  \(.api.commit[0:7])  \(.api.subject)\n  web  \(.web.commit[0:7])  \(.web.subject)\n  php  \(.runtime.php)"' "$dir/components.json"
  echo
  echo "Next: review the files, commit $RELEASES_DIR/, then: ./scripts/release.sh tag $version"
}

cmd_tag() {
  local version="${1:-}"
  [ -n "$version" ] || usage
  validate_version "$version"

  local dir="$RELEASES_DIR/v$version"
  is_blank "$dir/components.json" && die "$dir is not prepared. Run: ./scripts/release.sh prepare $version"
  is_blank "$dir/CHANGELOG.md" && die "$dir/CHANGELOG.md is empty."
  [ "$(tr -d '[:space:]' <"$dir/VERSION")" = "$version" ] || die "$dir/VERSION does not say $version."

  [ -z "$(git status --porcelain)" ] || die "Working tree is not clean. Commit the release files first, so the tag includes them."
  git rev-parse --quiet --verify "refs/tags/v$version" >/dev/null && die "Tag v$version already exists."

  # The recorded commits must match what this commit actually points at.
  local sub recorded actual key
  for sub in "${SUBMODULES[@]}"; do
    key="${sub#dostra-}"
    recorded="$(jq -r ".$key.commit" "$dir/components.json")"
    actual="$(git rev-parse "HEAD:$sub")"
    [ "$recorded" = "$actual" ] \
      || die "$sub is at ${actual:0:7} but components.json records ${recorded:0:7}. Re-run prepare (after deleting components.json) or fix the pointer."
  done

  git tag -a "v$version" -m "Dostra v$version"
  echo "Created tag v$version. Publish with: git push --follow-tags"
}

cmd_show() {
  local version="${1:-}"
  if [ -z "$version" ]; then
    version="$(list_versions | tail -n 1)"
    [ -n "$version" ] || die "No releases found in $RELEASES_DIR/."
  fi
  validate_version "$version"
  local file="$RELEASES_DIR/v$version/components.json"
  is_blank "$file" && die "$file is missing or empty."
  jq . "$file"
}

# ── Main ───────────────────────────────────────────────────────────────────────

require_tools

case "${1:-}" in
  prepare) shift; cmd_prepare "$@" ;;
  tag)     shift; cmd_tag "$@" ;;
  show)    shift; cmd_show "$@" ;;
  -h|--help|help) usage 0 ;;
  *) usage ;;
esac

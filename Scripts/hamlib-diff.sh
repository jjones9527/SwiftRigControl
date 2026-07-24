#!/usr/bin/env bash
#
# hamlib-diff.sh — Weekly upstream-Hamlib digest for SwiftRigControl.
#
# Reads the watched-path table out of HAMLIB_WATCH.md, fetches the
# latest Hamlib master, and emits a Markdown digest to stdout covering:
#   1. New Hamlib tagged releases since the stored watermark
#   2. Open Hamlib security advisories (always shown — never suppressed)
#   3. Commits touching any watched path since the stored watermark
#
# The .github/workflows/hamlib-watch.yml workflow pipes the output into
# `gh issue create` when non-empty, and updates the watermark file.
#
# Usage:
#   Scripts/hamlib-diff.sh                  # emit digest to stdout
#   Scripts/hamlib-diff.sh --dry-run        # emit digest, don't advance watermark
#   Scripts/hamlib-diff.sh --update-watermark <sha>  # write watermark and exit
#
# Environment:
#   HAMLIB_CLONE  path to a Hamlib clone. Defaults to ~/Developer/hamlib
#                 locally; the workflow points it at a fresh checkout.
#   GH_TOKEN      GitHub token for `gh` API calls. Optional locally;
#                 required in CI. Unauthenticated calls hit GitHub's
#                 lower rate limit but still work.

set -euo pipefail

# --- constants ---------------------------------------------------------

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WATCH_FILE="$REPO_ROOT/HAMLIB_WATCH.md"
WATERMARK_FILE="$REPO_ROOT/.hamlib-watermark"
HAMLIB_CLONE="${HAMLIB_CLONE:-$HOME/Developer/hamlib}"
HAMLIB_UPSTREAM="https://github.com/Hamlib/Hamlib.git"
DRY_RUN=0

# --- arg parsing -------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --update-watermark)
            shift
            [[ -z "${1:-}" ]] && { echo "error: --update-watermark needs a SHA" >&2; exit 2; }
            echo "$1" > "$WATERMARK_FILE"
            exit 0
            ;;
        -h|--help)
            sed -n '3,20p' "$0"; exit 0 ;;
        *) echo "error: unknown flag: $1" >&2; exit 2 ;;
    esac
done

# --- helpers -----------------------------------------------------------

log() { echo "[hamlib-diff] $*" >&2; }

ensure_hamlib_clone() {
    if [[ ! -d "$HAMLIB_CLONE/.git" ]]; then
        log "no clone at $HAMLIB_CLONE — cloning shallow"
        git clone --depth=200 "$HAMLIB_UPSTREAM" "$HAMLIB_CLONE" >&2
    else
        log "refreshing clone at $HAMLIB_CLONE"
        # A shallow clone can't diff far back — deepen if needed.
        git -C "$HAMLIB_CLONE" fetch --depth=500 origin master >&2 || \
            git -C "$HAMLIB_CLONE" fetch origin master >&2
        git -C "$HAMLIB_CLONE" checkout -q master 2>/dev/null || true
        git -C "$HAMLIB_CLONE" reset --hard origin/master >&2
    fi
}

# Parse the "| ... | `rigs/...` |" table rows in HAMLIB_WATCH.md and
# emit unique paths. Also emits shared/project-wide paths.
extract_watched_paths() {
    # Match backtick-quoted paths starting with rigs/, include/, tests/,
    # or bare toplevel files (NEWS, ChangeLog, ReleaseNotes_*.md).
    grep -oE '`(rigs/[a-z0-9_/.-]+|include/[a-z0-9_/.-]+|tests/[a-z0-9_/.-]+|NEWS|ChangeLog|ReleaseNotes_[0-9.]+\.md)`' "$WATCH_FILE" \
        | tr -d '`' | sort -u
}

# Warn about paths listed in HAMLIB_WATCH.md that no longer exist in
# Hamlib — usually means the file was renamed or removed upstream and
# our watch list needs updating.
warn_missing_paths() {
    local missing=()
    while IFS= read -r p; do
        if [[ ! -e "$HAMLIB_CLONE/$p" ]]; then
            missing+=("$p")
        fi
    done < <(extract_watched_paths)
    if (( ${#missing[@]} > 0 )); then
        echo "## Missing watched paths"
        echo
        echo "These paths are listed in \`HAMLIB_WATCH.md\` but no longer"
        echo "exist in the Hamlib repository. They may have been renamed or"
        echo "removed upstream — please update the watch file."
        echo
        for p in "${missing[@]}"; do echo "- \`$p\`"; done
        echo
    fi
}

read_watermark() {
    if [[ -f "$WATERMARK_FILE" ]]; then
        head -n1 "$WATERMARK_FILE" | tr -d '[:space:]'
    else
        # First run: default to 30 days ago so we don't dump years of
        # history into the first digest.
        git -C "$HAMLIB_CLONE" log --format='%H' --before='30 days ago' -n1 master 2>/dev/null || \
            git -C "$HAMLIB_CLONE" rev-list --max-parents=0 master | head -n1
    fi
}

section_new_tags() {
    local since="$1"
    local since_date
    since_date="$(git -C "$HAMLIB_CLONE" show -s --format=%cI "$since" 2>/dev/null || echo "")"

    # New tags reachable from master since watermark.
    local tags
    tags="$(git -C "$HAMLIB_CLONE" for-each-ref --sort=creatordate --format='%(refname:short)|%(creatordate:short)' refs/tags 2>/dev/null | \
        awk -F'|' -v d="$since_date" '$2 > substr(d,1,10)' | tail -20)"

    if [[ -z "$tags" ]]; then return; fi
    _ANYTHING_ACTIONABLE=1
    echo "## New Hamlib tags since $(echo "$since_date" | cut -c1-10)"
    echo
    while IFS='|' read -r tag date; do
        [[ -z "$tag" ]] && continue
        echo "- **[\`$tag\`](https://github.com/Hamlib/Hamlib/releases/tag/$tag)** — $date"
    done <<< "$tags"
    echo
}

section_advisories() {
    # $1 = watermark commit SHA — used to compute "since" date so we
    # can flag advisories published after the last digest as
    # actionable (rather than reprinting the same open advisories
    # every week).
    local since="$1"
    local since_date=""
    if [[ -n "$since" ]] && [[ -d "$HAMLIB_CLONE/.git" ]]; then
        since_date="$(git -C "$HAMLIB_CLONE" show -s --format=%cI "$since" 2>/dev/null | cut -c1-10)"
    fi

    if ! command -v gh >/dev/null 2>&1; then
        echo "## Security advisories"
        echo
        echo "_\`gh\` CLI not available — check <https://github.com/Hamlib/Hamlib/security/advisories> manually._"
        echo
        return
    fi

    local advisories_json
    advisories_json="$(gh api '/repos/Hamlib/Hamlib/security-advisories?per_page=10&state=published' 2>/dev/null || echo '[]')"

    # New advisories = those published on-or-after $since_date.
    local new_advisories=""
    if [[ -n "$since_date" ]]; then
        new_advisories="$(echo "$advisories_json" | \
            jq -r --arg since "$since_date" \
              '.[] | select(.state=="published" and (.published_at | tostring | .[0:10]) >= $since) | "- **[\(.ghsa_id)](\(.html_url))** — \(.summary) (\(.severity), published \(.published_at | tostring | .[0:10]))"' \
            2>/dev/null || true)"
    fi

    if [[ -n "$new_advisories" ]]; then
        echo "## NEW Hamlib security advisories since last digest"
        echo
        echo "The \`rigctld\` protocol bridge in SwiftRigControl is byte-compatible"
        echo "with Hamlib's \`rigctld\` — any Hamlib \`rigctld\` CVE is directly"
        echo "applicable and should be treated as drop-everything priority."
        echo
        echo "$new_advisories"
        echo
        # Flag as actionable so the workflow opens an issue.
        _ADVISORIES_NEW=1
    fi

    # Also list currently-open advisories as reference context, but
    # marked non-actionable so a run with no new signal doesn't emit
    # a whole digest.
    local all_open
    all_open="$(echo "$advisories_json" | \
        jq -r '.[] | select(.state=="published") | "- **[\(.ghsa_id)](\(.html_url))** — \(.summary) (\(.severity))"' \
        2>/dev/null || true)"

    if [[ -n "$all_open" ]] && [[ -n "${_ANYTHING_ACTIONABLE:-}" || -n "${_ADVISORIES_NEW:-}" ]]; then
        echo "## All currently-open Hamlib security advisories (reference)"
        echo
        echo "$all_open"
        echo
    fi
}

section_new_radios() {
    # Surfaces newly-added .c source files under the vendor directories
    # SwiftRigControl mirrors. Hamlib ships a new radio as either a
    # single `rigs/<vendor>/<model>.c` or a subdirectory of files (the
    # FTX-1 pattern). A .c add in a mirrored vendor dir is a strong
    # signal that either (a) a new radio landed and we should evaluate
    # porting it, or (b) an existing radio got a per-model refactor
    # split-out — either way, worth a look.
    #
    # We restrict to .c files because Hamlib adds are noisy: doc files,
    # shell scripts, and headers show up alongside the substantive
    # source. If a vendor tree only sees new headers/docs without a
    # corresponding .c, we skip the section for that commit.
    local since="$1"

    # Vendor directories to watch for new-radio adds. Kept in sync with
    # the vendors SwiftRigControl covers — extending SwiftRigControl to
    # a new vendor should also add the vendor dir here.
    local vendor_dirs=(
        rigs/icom
        rigs/yaesu
        rigs/kenwood
        rigs/tentec
        rigs/flexradio
    )

    # `git log --diff-filter=A --name-only` on the vendor dirs lists
    # every commit that added a file. We keep only .c files (skip .h,
    # docs, scripts, PDFs, etc.).
    local raw
    raw="$(git -C "$HAMLIB_CLONE" log \
        --no-merges \
        --diff-filter=A \
        --format='COMMIT %h %s' \
        --name-only \
        "$since..HEAD" \
        -- "${vendor_dirs[@]}" 2>/dev/null || true)"

    if [[ -z "$raw" ]]; then return; fi

    # Group by commit: each commit's added .c files under one bullet,
    # with the commit subject as the heading. Skip commits whose only
    # additions are non-.c files (headers, docs, scripts).
    local out=""
    local current_commit=""
    local current_subject=""
    local current_files=""
    local emit_block

    emit_block() {
        [[ -z "$current_commit" || -z "$current_files" ]] && return
        out+="- [\`$current_commit\`](https://github.com/Hamlib/Hamlib/commit/$current_commit) — $current_subject"$'\n'
        # De-dup + sort so the file list is stable.
        local unique_files
        unique_files="$(printf '%s\n' $current_files | sort -u)"
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            out+="    - \`$f\`"$'\n'
        done <<< "$unique_files"
    }

    while IFS= read -r line; do
        if [[ "$line" == COMMIT\ * ]]; then
            emit_block
            current_files=""
            # Parse: "COMMIT <hash> <subject>"
            current_commit="${line#COMMIT }"
            current_commit="${current_commit%% *}"
            current_subject="${line#COMMIT * }"
        elif [[ "$line" == *.c ]]; then
            current_files+="$line "
        fi
    done <<< "$raw"
    emit_block

    if [[ -z "$out" ]]; then return; fi

    _ANYTHING_ACTIONABLE=1
    echo "## Potentially new radios in Hamlib"
    echo
    echo "New \`.c\` source files added under vendor directories SwiftRigControl"
    echo "mirrors. Usually either a new radio landed upstream or an existing"
    echo "radio got a per-model refactor. Worth a look before triaging the"
    echo "commit list below."
    echo
    echo "$out"
}

section_watched_commits() {
    local since="$1"
    local paths_file
    paths_file="$(mktemp)"
    trap "rm -f '$paths_file'" RETURN

    extract_watched_paths > "$paths_file"

    if [[ ! -s "$paths_file" ]]; then
        log "no watched paths extracted from $WATCH_FILE"
        return
    fi

    local commits
    # shellcheck disable=SC2046
    commits="$(git -C "$HAMLIB_CLONE" log \
        --no-merges \
        --format='%h|%cI|%s' \
        "$since..HEAD" \
        -- $(cat "$paths_file") 2>/dev/null || true)"

    if [[ -z "$commits" ]]; then return; fi
    _ANYTHING_ACTIONABLE=1

    local count
    count="$(echo "$commits" | wc -l | tr -d ' ')"
    echo "## Commits touching watched Hamlib paths ($count since $(git -C "$HAMLIB_CLONE" show -s --format=%cs "$since" 2>/dev/null))"
    echo
    while IFS='|' read -r sha date subject; do
        [[ -z "$sha" ]] && continue
        # Show which watched files each commit touched — high-signal
        # context for the human triaging the digest.
        local files
        files="$(git -C "$HAMLIB_CLONE" show --name-only --format= "$sha" -- $(cat "$paths_file") 2>/dev/null | \
            sort -u | head -5 | sed 's/^/    - /')"
        echo "- [\`$sha\`](https://github.com/Hamlib/Hamlib/commit/$sha) — ${subject}"
        echo "  <sub>${date}</sub>"
        if [[ -n "$files" ]]; then
            echo "$files"
        fi
    done <<< "$commits"
    echo
}

# --- main --------------------------------------------------------------

ensure_hamlib_clone

# Head SHA — the workflow uses this to advance the watermark if the
# digest is non-empty.
HEAD_SHA="$(git -C "$HAMLIB_CLONE" rev-parse HEAD)"
WATERMARK="$(read_watermark)"
log "watermark: $WATERMARK"
log "hamlib HEAD: $HEAD_SHA"

# Only run diff sections if watermark is an ancestor of HEAD; otherwise
# the ranges won't resolve and we emit an unbounded log.
if ! git -C "$HAMLIB_CLONE" merge-base --is-ancestor "$WATERMARK" HEAD 2>/dev/null; then
    log "watermark $WATERMARK is not an ancestor of HEAD — resetting to 30 days ago"
    WATERMARK="$(git -C "$HAMLIB_CLONE" log --format='%H' --before='30 days ago' -n1 master 2>/dev/null | head -n1)"
fi

# Run sections into a temp file so section-set flags propagate.
_ANYTHING_ACTIONABLE=""
_ADVISORIES_NEW=""
DIGEST_FILE="$(mktemp)"
trap "rm -f '$DIGEST_FILE'" EXIT

{
    warn_missing_paths
    section_new_radios "$WATERMARK"
    section_new_tags "$WATERMARK"
    section_watched_commits "$WATERMARK"
    section_advisories "$WATERMARK"
} > "$DIGEST_FILE"

# Actionable = at least one new tag, one new advisory, or one commit
# touching a watched path. Bare "advisories still open" doesn't count
# — otherwise every weekly run reprints the same list.
if [[ -z "$_ANYTHING_ACTIONABLE" && -z "$_ADVISORIES_NEW" ]]; then
    log "no new signal since watermark — digest is empty"
    exit 0
fi

echo "_Hamlib upstream digest — $(date -u +%Y-%m-%d)_"
echo
echo "Watermark: [\`$(echo "$WATERMARK" | cut -c1-12)\`](https://github.com/Hamlib/Hamlib/commit/$WATERMARK) → [\`$(echo "$HEAD_SHA" | cut -c1-12)\`](https://github.com/Hamlib/Hamlib/commit/$HEAD_SHA)"
echo
cat "$DIGEST_FILE"
echo "---"
echo
echo "_Generated by \`Scripts/hamlib-diff.sh\` from \`HAMLIB_WATCH.md\`._"
echo "_Advance the watermark by running \`Scripts/hamlib-diff.sh --update-watermark $HEAD_SHA\`._"

# The workflow reads new_head_sha from GITHUB_OUTPUT to advance the
# watermark after opening the issue.
if [[ "$DRY_RUN" -eq 0 && -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "new_head_sha=$HEAD_SHA" >> "$GITHUB_OUTPUT"
fi

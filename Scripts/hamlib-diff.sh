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
        # v1.2.0 vendor expansion
        rigs/guohetec
        rigs/anytone
        rigs/elad
        rigs/commradio
        rigs/alinco
        rigs/aor
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

# Maps a Hamlib source file path to the SwiftRigControl file(s) a port
# of that change would touch. Emits one Swift path per line to stdout;
# emits nothing when the Hamlib path is genuinely out of scope (e.g.
# a documentation file we watch but don't mirror).
#
# The rules follow SwiftRigControl's layout as of v1.1.3:
#
# - Icom shared framing → the Icom protocol core + every Icom model
#   file (a change to icom.c potentially affects every Icom radio).
# - Icom per-model → the specific factory + capability database entry
#   + per-model CommandSet if one exists.
# - Kenwood shared → KenwoodProtocol.swift + every Kenwood radio file
#   (kenwood.c is used by Elecraft, Lab599, Flex, Xiegu too — those
#   downstream vendors are added when appropriate).
# - Yaesu newcat.c → YaesuCATProtocol.swift + every modern Yaesu; a
#   yaesu.c change → every Yaesu (classic + modern).
# - Ten-Tec framing → both TenTec protocols + every Ten-Tec radio.
# - rigctld tests/rigctl_parse.c and tests/rigctld.c → our Network/
#   layer, which is byte-compatible with Hamlib's rigctld.
# - include/hamlib/rig.h → CATProtocol.swift + capability traits (the
#   canonical Hamlib API surface, mirrored in Swift).
#
# When a Hamlib file has no clear Swift equivalent (e.g. rigs/dummy/
# on a shared file we don't mirror), the function stays silent so the
# port-work-orders section doesn't get polluted with dead-ends.
hamlib_to_swift() {
    local p="$1"
    case "$p" in
        # --- Icom -----------------------------------------------------
        rigs/icom/icom.c|rigs/icom/icom.h|rigs/icom/frame.c|rigs/icom/frame.h)
            # Shared CI-V framing / command dispatch — affects every
            # Icom radio in SwiftRigControl.
            echo "Sources/RigControl/Protocols/Icom/IcomCIVProtocol.swift"
            echo "Sources/RigControl/Protocols/Icom/CIVFrame.swift"
            echo "Sources/RigControl/Protocols/Icom/CIVCommandSet.swift"
            echo "Sources/RigControl/Protocols/Icom/CommandSets/StandardIcomCommandSet.swift"
            echo "Sources/RigControl/Protocols/Icom/IcomModels.swift  (+HF, +VHF variants)"
            ;;
        rigs/icom/xiegu.c)
            # Xiegu uses the Icom CI-V family under the hood.
            echo "Sources/RigControl/Protocols/Xiegu/XieguModels.swift"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+Xiegu.swift"
            ;;
        rigs/icom/ic7100.c)
            echo "Sources/RigControl/Protocols/Icom/CommandSets/IC7100CommandSet.swift"
            echo "Sources/RigControl/Protocols/Icom/IcomModels.swift  (ic7100 factory)"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+Icom.swift  (or +IcomFlagships/+IcomCompact)"
            ;;
        rigs/icom/ic706.c)
            echo "Sources/RigControl/Protocols/Icom/CommandSets/IC706CommandSet.swift"
            echo "Sources/RigControl/Protocols/Icom/IcomModels.swift  (ic706/ic706MKII/ic706MKIIG factories)"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+IcomLegacy.swift"
            ;;
        rigs/icom/ic746.c)
            echo "Sources/RigControl/Protocols/Icom/CommandSets/IC746CommandSet.swift"
            echo "Sources/RigControl/Protocols/Icom/IcomModels+HF.swift  (ic746/ic746PRO factories)"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+Icom.swift  (or +IcomLegacy)"
            ;;
        rigs/icom/ic756.c)
            echo "Sources/RigControl/Protocols/Icom/CommandSets/IC756CommandSet.swift"
            echo "Sources/RigControl/Protocols/Icom/IcomModels+HF.swift  (ic756/PRO/PROII/PROIII)"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+IcomLegacy.swift"
            ;;
        rigs/icom/ic9100.c)
            # Also covers IC-9700 in Hamlib (shared CI-V family).
            echo "Sources/RigControl/Protocols/Icom/CommandSets/IC9700CommandSet.swift"
            echo "Sources/RigControl/Protocols/Icom/IcomModels.swift  (ic9700 factory)"
            echo "Sources/RigControl/Protocols/Icom/IcomModels+HF.swift  (ic9100 factory)"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+Icom.swift"
            ;;
        rigs/icom/ic7300.c)
            # Hamlib's ic7300.c also references IC-905 and IC-9700.
            echo "Sources/RigControl/Protocols/Icom/IcomModels.swift  (ic7300/ic7300MK2/ic9700)"
            echo "Sources/RigControl/Protocols/Icom/IcomModels+VHF.swift  (ic905)"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+Icom.swift"
            ;;
        rigs/icom/ic7600.c|rigs/icom/ic7610.c|rigs/icom/ic7700.c|rigs/icom/ic7760.c|rigs/icom/ic7800.c|rigs/icom/ic785x.c|rigs/icom/ic7410.c|rigs/icom/ic7000.c|rigs/icom/ic7200.c|rigs/icom/ic718.c|rigs/icom/ic703.c|rigs/icom/ic735.c|rigs/icom/ic751.c|rigs/icom/ic820h.c|rigs/icom/ic910.c|rigs/icom/ic970.c|rigs/icom/icf8101.c)
            local base
            base="$(basename "$p" .c)"
            echo "Sources/RigControl/Protocols/Icom/IcomModels.swift  (${base} factory)"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+Icom.swift  (or +IcomLegacy/+IcomFlagships)"
            ;;
        rigs/icom/ic2730.c|rigs/icom/id4100.c|rigs/icom/id5100.c|rigs/icom/id31.c|rigs/icom/id51.c|rigs/icom/id52plus.c|rigs/icom/ic92d.c|rigs/icom/icr30.c|rigs/icom/icr75.c|rigs/icom/icr8600.c|rigs/icom/icr9500.c|rigs/icom/icr6.c|rigs/icom/icr20.c|rigs/icom/icrx7.c|rigs/icom/id1.c|rigs/icom/icr7000.c)
            local base
            base="$(basename "$p" .c)"
            echo "Sources/RigControl/Protocols/Icom/IcomModels+VHF.swift  (${base} factory)"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+Icom.swift  (or +IcomCompact)"
            ;;

        # --- Kenwood family (Kenwood + Elecraft + Lab599 + Flex) ------
        rigs/kenwood/kenwood.c|rigs/kenwood/kenwood.h)
            # Shared Kenwood text-protocol logic — the safety patch in
            # v1.1.2 was almost entirely driven by this file.
            echo "Sources/RigControl/Protocols/Kenwood/KenwoodProtocol.swift  (+extensions)"
            echo "Sources/RigControl/Protocols/Kenwood/KenwoodModels.swift"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+Kenwood.swift"
            echo "Sources/RigControl/Protocols/Elecraft/  (downstream — same protocol base)"
            echo "Sources/RigControl/Protocols/Kenwood/Lab599Models.swift  (downstream)"
            echo "Sources/RigControl/Protocols/Kenwood/FlexModels.swift  (downstream)"
            ;;
        rigs/kenwood/elecraft.c)
            echo "Sources/RigControl/Protocols/Elecraft/ElecraftProtocol.swift  (+extensions)"
            echo "Sources/RigControl/Protocols/Elecraft/ElecraftModels.swift"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+Elecraft.swift"
            ;;
        rigs/kenwood/k2.c|rigs/kenwood/k3.c)
            # k3.c covers KX2, KX3, K3, K3S, K4 in Hamlib.
            echo "Sources/RigControl/Protocols/Elecraft/ElecraftModels.swift  (${p##*/} factory)"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+Elecraft.swift"
            ;;
        rigs/kenwood/thd72.c|rigs/kenwood/thd74.c)
            local base
            base="$(basename "$p" .c)"
            echo "Sources/RigControl/Protocols/Kenwood/THD72Protocol.swift  (if TH-D72-specific)"
            echo "Sources/RigControl/Protocols/Kenwood/KenwoodModels.swift  (${base} factory)"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+Kenwood.swift"
            ;;
        rigs/kenwood/ts590.c|rigs/kenwood/ts480.c|rigs/kenwood/ts570.c|rigs/kenwood/ts850.c|rigs/kenwood/ts870s.c|rigs/kenwood/ts890s.c|rigs/kenwood/ts990s.c|rigs/kenwood/ts450s.c|rigs/kenwood/ts690.c|rigs/kenwood/ts940.c|rigs/kenwood/ts950.c)
            local base
            base="$(basename "$p" .c)"
            echo "Sources/RigControl/Protocols/Kenwood/KenwoodModels.swift  (${base} factory)"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+Kenwood.swift"
            ;;
        rigs/kenwood/ts2000.c)
            # ts2000.c holds both TS-2000 AND SDR-Console (which
            # emulates TS-2000 CAT and registers under this file).
            echo "Sources/RigControl/Protocols/Kenwood/KenwoodModels.swift  (ts2000 factory)"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+Kenwood.swift"
            echo "Sources/RigControl/Protocols/Kenwood/FlexModels.swift  (sdrConsole factory)"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+Flex.swift"
            ;;
        rigs/kenwood/pihpsdr.c)
            # PiHPSDR is a distinct Kenwood-family SDR client (TS-2000
            # emulation per the file header).
            echo "Sources/RigControl/Protocols/Kenwood/FlexModels.swift  (pihpsdr factory)"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+Flex.swift"
            ;;
        rigs/kenwood/tx500.c)
            echo "Sources/RigControl/Protocols/Kenwood/Lab599Models.swift"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+Lab599.swift"
            ;;
        rigs/kenwood/flex.c|rigs/kenwood/flex6xxx.c|rigs/kenwood/flex.h)
            echo "Sources/RigControl/Protocols/Kenwood/FlexModels.swift"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+Flex.swift"
            ;;

        # --- Yaesu ----------------------------------------------------
        rigs/yaesu/newcat.c|rigs/yaesu/newcat.h)
            # Every modern Yaesu (FT-710/891/950/991/991A/2000/FTDX-*)
            # AND the FTX-1 (which is built on top of newcat with
            # FTX-1-specific extensions in rigs/yaesu/ftx1/).
            echo "Sources/RigControl/Protocols/Yaesu/YaesuCATProtocol.swift  (+extensions)"
            echo "Sources/RigControl/Protocols/Yaesu/YaesuModels.swift"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+YaesuModern.swift"
            ;;
        rigs/yaesu/ftx1/*.c|rigs/yaesu/ftx1/*.h|rigs/yaesu/ftx1.c|rigs/yaesu/ftx1.h)
            # FTX-1 (2025) — newcat-based with FTX-1-specific mode
            # codes, memory-mode escape prelude, and per-subsystem
            # extensions in the ftx1/ subdirectory.
            echo "Sources/RigControl/Protocols/Yaesu/YaesuCATProtocol.swift  (Quirks.ftx1)"
            echo "Sources/RigControl/Protocols/Yaesu/YaesuModels.swift  (ftx1 factory)"
            ;;
        rigs/yaesu/yaesu.c|rigs/yaesu/yaesu.h)
            # Classic Yaesu framing — FT-100/817/818/847/857/897/920/1000MP.
            echo "Sources/RigControl/Protocols/Yaesu/YaesuCATProtocol.swift"
            echo "Sources/RigControl/Protocols/Yaesu/YaesuModels.swift"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+YaesuLegacy.swift"
            ;;
        rigs/yaesu/ft710.c|rigs/yaesu/ft891.c|rigs/yaesu/ft950.c|rigs/yaesu/ft991.c|rigs/yaesu/ft2000.c|rigs/yaesu/ftdx10.c|rigs/yaesu/ftdx101.c|rigs/yaesu/ftdx101mp.c|rigs/yaesu/ft1200.c|rigs/yaesu/ft3000.c|rigs/yaesu/ft5000.c|rigs/yaesu/ft9000.c|rigs/yaesu/ft450.c)
            local base
            base="$(basename "$p" .c)"
            echo "Sources/RigControl/Protocols/Yaesu/YaesuModels.swift  (${base} factory)"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+YaesuModern.swift"
            ;;
        rigs/yaesu/ft817.c|rigs/yaesu/ft847.c|rigs/yaesu/ft857.c|rigs/yaesu/ft897.c|rigs/yaesu/ft920.c|rigs/yaesu/ft100.c|rigs/yaesu/ft1000mp.c)
            local base
            base="$(basename "$p" .c)"
            echo "Sources/RigControl/Protocols/Yaesu/YaesuModels.swift  (${base} factory)"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+YaesuLegacy.swift"
            ;;

        # --- Ten-Tec --------------------------------------------------
        rigs/tentec/tentec.c|rigs/tentec/tentec.h|rigs/tentec/tentec2.c|rigs/tentec/tentec2.h)
            echo "Sources/RigControl/Protocols/TenTec/TenTecOrionProtocol.swift"
            echo "Sources/RigControl/Protocols/TenTec/TenTecLegacyProtocol.swift"
            echo "Sources/RigControl/Protocols/TenTec/TenTecRadioDefinitions.swift"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+TenTec.swift"
            ;;
        rigs/tentec/orion.c|rigs/tentec/orion.h)
            echo "Sources/RigControl/Protocols/TenTec/TenTecOrionProtocol.swift"
            echo "Sources/RigControl/Protocols/TenTec/TenTecRadioDefinitions.swift  (orion/orionII/eagle)"
            ;;
        rigs/tentec/jupiter.c)
            echo "Sources/RigControl/Protocols/TenTec/TenTecLegacyProtocol.swift"
            echo "Sources/RigControl/Protocols/TenTec/TenTecRadioDefinitions.swift  (jupiter)"
            ;;
        rigs/tentec/pegasus.c)
            echo "Sources/RigControl/Protocols/TenTec/TenTecLegacyProtocol.swift"
            echo "Sources/RigControl/Protocols/TenTec/TenTecRadioDefinitions.swift  (pegasus)"
            ;;

        # --- rigctld & top-level API ---------------------------------
        tests/rigctl_parse.c|tests/rigctld.c)
            # The rigctld protocol bridge — byte-compatible with Hamlib's.
            echo "Sources/RigControl/Network/RigctldCommandHandler.swift"
            echo "Sources/RigControl/Network/RigctldCommandParser.swift"
            echo "Sources/RigControl/Network/RigControlServer.swift"
            ;;
        include/hamlib/rig.h)
            # Canonical Hamlib API surface — SwiftRigControl mirrors it
            # via CATProtocol + capability traits.
            echo "Sources/RigControl/Core/CATProtocol.swift"
            echo "Sources/RigControl/Core/CATProtocolTraits.swift"
            ;;

        # --- v1.2.0 new-vendor protocol adapters ---------------------
        rigs/guohetec/guohetec.c|rigs/guohetec/guohetec.h)
            echo "Sources/RigControl/Protocols/Guohetec/GuohetecProtocol.swift"
            echo "Sources/RigControl/Protocols/Guohetec/GuohetecModels.swift"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+Guohetec.swift"
            ;;
        rigs/guohetec/q900.c|rigs/guohetec/pmr171.c)
            local base
            base="$(basename "$p" .c)"
            echo "Sources/RigControl/Protocols/Guohetec/GuohetecModels.swift  (${base} factory)"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+Guohetec.swift"
            ;;
        rigs/anytone/anytone.c|rigs/anytone/anytone.h)
            echo "Sources/RigControl/Protocols/Anytone/AnytoneProtocol.swift"
            echo "Sources/RigControl/Protocols/Anytone/AnytoneModels.swift"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+Anytone.swift"
            ;;
        rigs/elad/fdm_duo.c)
            echo "Sources/RigControl/Protocols/Elad/EladProtocol.swift"
            echo "Sources/RigControl/Protocols/Elad/EladModels.swift  (fdmDUO factory)"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+Elad.swift"
            ;;
        rigs/commradio/ctx10.c)
            echo "Sources/RigControl/Protocols/CommRadio/CommRadioProtocol.swift"
            echo "Sources/RigControl/Protocols/CommRadio/CommRadioModels.swift  (ctx10 factory)"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+CommRadio.swift"
            ;;
        rigs/alinco/dx77.c)
            echo "Sources/RigControl/Protocols/Alinco/AlincoProtocol.swift"
            echo "Sources/RigControl/Protocols/Alinco/AlincoModels.swift  (dx77 / dxSR8 factories)"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+Alinco.swift"
            ;;
        rigs/aor/ar8600.c|rigs/aor/ar7030.c)
            local base
            base="$(basename "$p" .c)"
            echo "Sources/RigControl/Protocols/AOR/AORProtocol.swift"
            echo "Sources/RigControl/Protocols/AOR/AORModels.swift  (${base} factory)"
            echo "Sources/RigControl/Models/RadioCapabilitiesDatabase+AOR.swift"
            ;;

        # --- Docs (informational, no code port) ----------------------
        NEWS|ChangeLog|ReleaseNotes_*.md)
            # No Swift equivalent — read for release-note context.
            ;;

        *)
            # Unknown path — emit nothing rather than a wrong guess.
            ;;
    esac
}

# Returns 0 if the subject looks like a low-signal refactor / cosmetic
# change (skimmable), 1 if it looks like a substantive fix, feature,
# or behavior change (port candidate). Default is 1 — better to
# over-surface than to hide something actionable.
#
# The refactor patterns are the distinctive ones. Fix/feature language
# is broad ("update", "add", "implement" can all be substantive) so we
# treat unknowns as fixes.
is_refactor_subject() {
    local subject="$1"
    # Case-insensitive match against a bar-delimited alternation.
    # Anchored fragments — "reduce", "cleanup", "tidy" are unambiguous
    # refactor language in Hamlib's history. "make X boolean/const/static"
    # is the pervasive C-modernization pattern in recent commits.
    local pattern='(^|[^a-z])(make (a few |more |some )?(variables|switches|flags|data|routines|extcmds|columns) (boolean|const|static|inline)|make .* (boolean|const|static)|(routines|data|columns|flags|variables) (made|converted to) (static|const|boolean)|reduce ([a-z ]+)?(scoping|scope)|scope reduction|shrink scope|clean up|cleanup|tidy up|tidy|rename macro|quell (clang |gcc )?warning|silence (clang |gcc )?warning|remove old-fashioned|remove redundant|remove all traces|change ncboolean|change .* to a .* typedef|convert .* to bool|get rid of static|first steps toward removing|use variable instead|use the data in|move tuning step list|update the last of|update .* (version|comments|news|releasenotes)|use bounded %|update news|trading a little more data)'
    local lc
    lc="$(echo "$subject" | tr '[:upper:]' '[:lower:]')"
    if [[ "$lc" =~ $pattern ]]; then
        return 0  # is a refactor
    fi
    return 1  # not obviously a refactor → treat as substantive
}

# Global buffer of unique Hamlib paths touched by any commit in the
# digest. Populated by section_watched_commits and section_new_radios
# as they iterate; consumed by section_port_work_orders at the end.
_TOUCHED_HAMLIB_PATHS=""

_record_touched_paths() {
    # Append newline-separated paths (dedup happens at emit time).
    _TOUCHED_HAMLIB_PATHS+="$1"$'\n'
}

section_port_work_orders() {
    # For every unique Hamlib source file touched in the digest, emit
    # the SwiftRigControl file(s) a port would touch. Turns the commit
    # list from "here's what changed" into "here's what to edit."
    [[ -z "$_TOUCHED_HAMLIB_PATHS" ]] && return

    local unique_paths
    unique_paths="$(echo "$_TOUCHED_HAMLIB_PATHS" | grep -v '^$' | sort -u)"
    [[ -z "$unique_paths" ]] && return

    local out=""
    local any_mapping=0
    while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        local mapped
        mapped="$(hamlib_to_swift "$path")"
        if [[ -n "$mapped" ]]; then
            out+="**\`$path\`**"$'\n'
            while IFS= read -r swift; do
                [[ -z "$swift" ]] && continue
                out+="- \`$swift\`"$'\n'
            done <<< "$mapped"
            out+=$'\n'
            any_mapping=1
        fi
    done <<< "$unique_paths"

    [[ "$any_mapping" -eq 0 ]] && return

    echo "## Port work orders"
    echo
    echo "For every unique Hamlib file touched above, the SwiftRigControl file(s)"
    echo "a port would edit. Use as a work-order checklist when porting the fixes"
    echo "in the previous section."
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

    local since_date
    since_date="$(git -C "$HAMLIB_CLONE" show -s --format=%cs "$since" 2>/dev/null)"

    # Partition into two buckets.
    local fixes=""
    local refactors=""
    local fix_count=0
    local refactor_count=0

    while IFS='|' read -r sha date subject; do
        [[ -z "$sha" ]] && continue
        local raw_files
        raw_files="$(git -C "$HAMLIB_CLONE" show --name-only --format= "$sha" -- $(cat "$paths_file") 2>/dev/null | \
            sort -u | head -5)"
        local files=""
        if [[ -n "$raw_files" ]]; then
            files="$(echo "$raw_files" | sed 's/^/    - /')"
            # Feed the port-work-orders section, but only for the fix
            # bucket — refactors don't warrant port work orders.
            if ! is_refactor_subject "$subject"; then
                _record_touched_paths "$raw_files"
            fi
        fi
        local entry
        entry="- [\`$sha\`](https://github.com/Hamlib/Hamlib/commit/$sha) — ${subject}
  <sub>${date}</sub>"
        if [[ -n "$files" ]]; then
            entry+="
$files"
        fi

        if is_refactor_subject "$subject"; then
            refactors+="$entry"$'\n'
            refactor_count=$((refactor_count + 1))
        else
            fixes+="$entry"$'\n'
            fix_count=$((fix_count + 1))
        fi
    done <<< "$commits"

    if [[ "$fix_count" -gt 0 ]]; then
        echo "## Fixes / behavior changes touching watched Hamlib paths ($fix_count since $since_date)"
        echo
        echo "_Fixes, new capabilities, and behavior changes — port candidates._"
        echo
        echo "$fixes"
    fi

    if [[ "$refactor_count" -gt 0 ]]; then
        echo "<details><summary><b>Refactors / cosmetic changes ($refactor_count) — skim only</b></summary>"
        echo
        echo "_Cleanup, renames, boolean/const conversions, scope reductions — not typically portable, but included for completeness._"
        echo
        echo "$refactors"
        echo "</details>"
        echo
    fi
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
    section_port_work_orders
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

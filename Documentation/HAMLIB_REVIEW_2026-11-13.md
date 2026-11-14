# Hamlib upstream review — 2026-11-13

Compared the reviewed baseline `9199f8a239aed26b5eb0ee9c1a73bf51580483ce`
with freshly fetched master `1b3fb4a6a30652c37a45b38cd766f5de515231b3`
(November 10). Also checked maintenance branch Hamlib-4.7 at
`214bf9d275f218fd40169785c27e819c0f355d4a`, releases, and published security
advisories. Used an isolated temporary clone; the existing Hamlib checkout
and review watermark remain unchanged. The applicable G90 fix and the first
TX-meter increment have now been implemented locally; see validation below.

## Findings

| Upstream change | Local impact | Recommended work |
| --- | --- | --- |
| [G90 SWR validation](https://github.com/Hamlib/Hamlib/commit/f78a899fe) | Direct bug candidate. `IcomCIVProtocol.getSWRMeter()` checks response lengths but passes unchecked BCD to `BCDEncoding.decodeLevel`. For example, `02 2C` is accepted despite an invalid decimal nibble. | First: validate the G90 response command and BCD digits before decoding. Add valid, malformed, wrong-command, and rejection-response tests. Preserve the existing separate RFPOWER malformed-BCD workaround. |
| [K4 power meter](https://github.com/Hamlib/Hamlib/commit/b7a9bfab7) | Applies to the pending Elecraft TX-meter feature. Upstream now uses one `PO` query and validates exactly four decimal digits. Watts are raw / 10; normalized RFPOWER_METER is raw / 1000. | Use this implementation as the reference when adding K4 TX meters; do not derive power from the previous bar-graph path. Include low-power and malformed-response cases. |
| [Yaesu narrow flag validation](https://github.com/Hamlib/Hamlib/commit/1b3fb4a6a) | Upstream rejects `NA` values other than 0 or 1. Our current filter reader queries `SH0` and has no `NA` query path. | No direct port. Carry the validation requirement into future exact-bandwidth support. The existing SH reader is a separate implementation, not proof of equivalent bandwidth behavior. |
| [Daemon socket ownership](https://github.com/Hamlib/Hamlib/commit/a31705698) and [merge](https://github.com/Hamlib/Hamlib/commit/dba524fef) | Hamlib duplicates descriptors before wrapping input/output FILE streams, preventing multiple closes of the accepted descriptor. It also raises the listen backlog and adds session stress tests. Our server owns an NWConnection and cancels it; it does not use fdopen/fclose on shared descriptors. | No direct C fix to port. Concurrent connect/disconnect testing remains a useful future server check. |

The net master diff touches 19 files. Its four new first-parent entries
are the three radio fixes and the daemon-client merge. Inspecting the net
tree diff avoids mistaking old history exposed by shallow boundaries for
new work.

## Maintenance branch, releases, and advisories

Hamlib-4.7 includes the same three November 10 radio fixes. Its November 5
changes address C frontend startup/cleanup, asynchronous reader lifetime,
pipe creation, pthread error handling, Morse queue initialization, queue
release on oversized text, empty Morse text, and the settling delay when
no rig port exists. These are not directly portable to our Swift backend
architecture; no corresponding pthread/FIFO implementation was identified
in the reviewed Swift paths.

The [latest published release](https://github.com/Hamlib/Hamlib/releases/tag/4.7.2)
remains 4.7.2 (June 21). The GitHub releases API returned no newer release.
The [published advisory feed](https://github.com/Hamlib/Hamlib/security/advisories)
returned eight advisories, none published or updated after the November 4
baseline. This does not replace the earlier advisory applicability review.

## Order for continuing parity work

1. Port and test the G90 SWR validation fix.
2. Resume ROADMAP 5.10.4 Kenwood/Elecraft TX meters, using the corrected K4
   PO behavior above.
3. Continue the separately tracked split-mode VFO targeting and antenna
   capability gaps.

## Implementation and validation

Implemented locally on November 13:

- G90 SWR rejects malformed BCD digits, wrong command echoes, and invalid
  lengths. NAK is reported as a command rejection. The existing RFPOWER
  full-scale workaround remains covered by its regression tests.
- K4 power uses one PO query, exactly four ASCII decimal digits, watts =
  raw / 10 and normalized power = raw / 1000. SWR and ALC use validated
  TM records, matching Hamlib's field scaling.
- TS-590S/SG SWR, compression and ALC consume all three RM replies before
  validating their fields. Power reads IF to check TX state (this backend
  has no Hamlib-style PTT cache), then SM0. Watts use Hamlib's calibration
  and rounding; normalized power uses raw / 30 independently.
- Catalog capabilities and rigctld expose these meters only on the
  implemented models. Remaining TS-480/2000/890S/990S, K3/K3S/KX and Flex
  meter work is still tracked in ROADMAP 5.10.4.

Xcode build-for-testing succeeded. The full Xcode test run passed:
**1,404 passed, 0 failed, 57 skipped** (1,461 total). Regression coverage
includes malformed replies, valid calibration points, RX power behavior,
RM reply consumption, unsupported-model gates, and rigctld numeric output.
No hardware validation was performed.

The watermark remains at the previous baseline until this work is landed;
this document records the disposition through `1b3fb4a6a`.

# Migrating to SwiftRigControl v1.1.0

v1.1.0 is the first feature release after v1.0.6. It moves every
public radio symbol under a vendor namespace, adds a TCP transport
+ Flex/PowerSDR/Thetis definitions, and ships targeted serial-port
auto-detection. This document walks through the breaking change
and the new APIs you can opt into.

## TL;DR

| Before                                            | After                                                  |
| ------------------------------------------------- | ------------------------------------------------------ |
| `.icomIC7300()`                                   | `.Icom.ic7300()`                                       |
| `.icomIC7600(civAddress: 0x7B)`                   | `.Icom.ic7600(civAddress: 0x7B)`                       |
| `.yaesuFTDX10`                                    | `.Yaesu.ftdx10`                                        |
| `.kenwoodTS890S`                                  | `.Kenwood.ts890S`                                      |
| `.elecraftK3`                                     | `.Elecraft.k3`                                         |
| `.xieguG90()`                                     | `.Xiegu.g90`                                           |
| `.lab599TX500`                                    | `.Lab599.tx500`                                        |
| `RadioCapabilitiesDatabase.icomIC7300`            | `RadioCapabilitiesDatabase.Icom.ic7300`                |
| `RadioCapabilitiesDatabase.yaesuFTDX10`           | `RadioCapabilitiesDatabase.Yaesu.ftdx10`               |

The rest of this document covers the *why*, the full mapping, and
the new APIs.

---

## 1. Vendor namespaces (BREAKING)

### Why

`RadioDefinition` and `RadioCapabilitiesDatabase` previously
exposed every supported radio as a top-level static member, with
`vendor` baked into the name (`icomIC7300`, `yaesuFTDX10`,
`kenwoodTS890S`). With ~98 radios across 8 vendors, autocomplete
became unhelpful — typing `.i` matched ~45 Icoms before you could
filter further.

The namespaces fix this. Typing `.Icom.` now filters autocomplete
to just Icom radios, `.Yaesu.` to just Yaesu, and so on. The
naming convention drops the vendor prefix from the leaf name
(`.icomIC7300()` → `.Icom.ic7300()`), since the namespace already
encodes it.

### What changed

- Eight nested namespace enums on `RadioDefinition` and
  `RadioCapabilitiesDatabase`: `Icom`, `Yaesu`, `Kenwood`,
  `Elecraft`, `Xiegu`, `TenTec`, `Lab599`, `Flex`.
- Every previously-flat `.vendorModel` name removed and re-added
  under the appropriate namespace, lowercase-first.
- No deprecation shims. The flat names are gone in v1.1.0.

### What did *not* change

- `IcomRadioModel` enum cases. `IcomRadioModel.ic7300`,
  `.ic9700`, etc. still exist — these identify radios *inside*
  the Icom CI-V protocol implementation (where they always
  belonged), not in the public catalog.
- Function and VFO-operation preset sets:
  `.icomIC7600Funcs`, `.icomStandard`, `.yaesuStandard`, etc. on
  `Set<RigFunction>` and `Set<VFOOperation>` keep their existing
  names.
- All wire bytes. Migration is purely a rename — your radio
  behaves identically.

### Migration recipe

For each `.vendorModel` reference in your code:

1. **Find the matching vendor namespace.** `icomXxx` → `.Icom`,
   `yaesuXxx` → `.Yaesu`, etc.
2. **Strip the vendor prefix** from the leaf name and lowercase
   its first character.
   - `icomIC7300` → `ic7300`
   - `icomID51` → `id51`
   - `icomICR30` → `icR30` (the `R` for Receiver stays
     capitalized to disambiguate from `ic*` transceivers)
   - `yaesuFTDX10` → `ftdx10`
   - `yaesuFT991A` → `ft991A`
   - `kenwoodTS890S` → `ts890S`
   - `kenwoodTHD75` → `thd75`
   - `elecraftK3` → `k3`
   - `xieguG90` → `g90`
   - `lab599TX500` → `tx500`
3. **Combine into the namespaced form**: `.Vendor.leafname`.

### Full mapping

#### Icom (44 radios)

| Old                                  | New                          |
| ------------------------------------ | ---------------------------- |
| `.icomIC7300()`                      | `.Icom.ic7300()`             |
| `.icomIC7300MK2()`                   | `.Icom.ic7300MK2()`          |
| `.icomIC7600()`                      | `.Icom.ic7600()`             |
| `.icomIC7610()`                      | `.Icom.ic7610()`             |
| `.icomIC7700()`                      | `.Icom.ic7700()`             |
| `.icomIC7760()`                      | `.Icom.ic7760()`             |
| `.icomIC7800()`                      | `.Icom.ic7800()`             |
| `.icomIC7850()`                      | `.Icom.ic7850()`             |
| `.icomIC7851()`                      | `.Icom.ic7851()`             |
| `.icomIC7100()`                      | `.Icom.ic7100()`             |
| `.icomIC9100()`                      | `.Icom.ic9100()`             |
| `.icomIC9700()`                      | `.Icom.ic9700()`             |
| `.icomIC705()`                       | `.Icom.ic705()`              |
| `.icomIC905()`                       | `.Icom.ic905()`              |
| `.icomIC910H()`                      | `.Icom.ic910H()`             |
| `.icomID31()`                        | `.Icom.id31()`               |
| `.icomID51()`                        | `.Icom.id51()`               |
| `.icomID52()`                        | `.Icom.id52()`               |
| `.icomIC92D()`                       | `.Icom.ic92D()`              |
| `.icomICR30()`                       | `.Icom.icR30()`              |
| `.icomICR8600()`                     | `.Icom.icR8600()`            |
| `.icomICR9500()`                     | `.Icom.icR9500()`            |
| `.icomICR75()`                       | `.Icom.icR75()`              |

…and the same pattern for the remaining ~20 legacy Icoms
(IC-756 family, IC-746, IC-706 family, IC-735, etc.).

#### Yaesu (25 radios)

| Old                | New                  |
| ------------------ | -------------------- |
| `.yaesuFTDX10`     | `.Yaesu.ftdx10`      |
| `.yaesuFTDX101D`   | `.Yaesu.ftdx101D`    |
| `.yaesuFTDX101MP`  | `.Yaesu.ftdx101MP`   |
| `.yaesuFTDX3000`   | `.Yaesu.ftdx3000`    |
| `.yaesuFTDX5000`   | `.Yaesu.ftdx5000`    |
| `.yaesuFTDX1200`   | `.Yaesu.ftdx1200`    |
| `.yaesuFTDX9000`   | `.Yaesu.ftdx9000`    |
| `.yaesuFT991`      | `.Yaesu.ft991`       |
| `.yaesuFT991A`     | `.Yaesu.ft991A`      |
| `.yaesuFT950`      | `.Yaesu.ft950`       |
| `.yaesuFT920`      | `.Yaesu.ft920`       |
| `.yaesuFT891`      | `.Yaesu.ft891`       |
| `.yaesuFT847`      | `.Yaesu.ft847`       |
| `.yaesuFT818`      | `.Yaesu.ft818`       |
| `.yaesuFT817`      | `.Yaesu.ft817`       |
| `.yaesuFT710`      | `.Yaesu.ft710`       |
| `.yaesuFT450`      | `.Yaesu.ft450`       |
| `.yaesuFT450D`     | `.Yaesu.ft450D`      |
| `.yaesuFT2000`     | `.Yaesu.ft2000`      |
| `.yaesuFT1000MP`   | `.Yaesu.ft1000MP`    |
| `.yaesuFT100`      | `.Yaesu.ft100`       |
| `.yaesuFT897`      | `.Yaesu.ft897`       |
| `.yaesuFT897D`     | `.Yaesu.ft897D`      |
| `.yaesuFT857`      | `.Yaesu.ft857`       |
| `.yaesuFT857D`     | `.Yaesu.ft857D`      |

#### Kenwood (17 radios)

| Old                 | New                   |
| ------------------- | --------------------- |
| `.kenwoodTS990S`    | `.Kenwood.ts990S`     |
| `.kenwoodTS890S`    | `.Kenwood.ts890S`     |
| `.kenwoodTS590S`    | `.Kenwood.ts590S`     |
| `.kenwoodTS590SG`   | `.Kenwood.ts590SG`    |
| `.kenwoodTS870S`    | `.Kenwood.ts870S`     |
| `.kenwoodTS850S`    | `.Kenwood.ts850S`     |
| `.kenwoodTS570D`    | `.Kenwood.ts570D`     |
| `.kenwoodTS570S`    | `.Kenwood.ts570S`     |
| `.kenwoodTS480SAT`  | `.Kenwood.ts480SAT`   |
| `.kenwoodTS480HX`   | `.Kenwood.ts480HX`    |
| `.kenwoodTS2000`    | `.Kenwood.ts2000`     |
| `.kenwoodTMD710`    | `.Kenwood.tmd710`     |
| `.kenwoodTMV71`     | `.Kenwood.tmv71`      |
| `.kenwoodTHD75`     | `.Kenwood.thd75`      |
| `.kenwoodTHD74`     | `.Kenwood.thd74`      |
| `.kenwoodTHD72A`    | `.Kenwood.thd72A`     |
| `.kenwoodTHD72`     | `.Kenwood.thd72`      |

#### Elecraft (6 radios)

| Old              | New                 |
| ---------------- | ------------------- |
| `.elecraftK2`    | `.Elecraft.k2`      |
| `.elecraftK3`    | `.Elecraft.k3`      |
| `.elecraftK3S`   | `.Elecraft.k3S`     |
| `.elecraftK4`    | `.Elecraft.k4`      |
| `.elecraftKX2`   | `.Elecraft.kx2`     |
| `.elecraftKX3`   | `.Elecraft.kx3`     |

#### Xiegu (3 radios)

| Old             | New                |
| --------------- | ------------------ |
| `.xieguG90`     | `.Xiegu.g90`       |
| `.xieguX6100`   | `.Xiegu.x6100`     |
| `.xieguX6200`   | `.Xiegu.x6200`     |

#### Lab599 (1 radio)

| Old              | New                |
| ---------------- | ------------------ |
| `.lab599TX500`   | `.Lab599.tx500`    |

### `Optional<RadioDefinition>` gotcha

Swift's leading-dot member sugar fails through `Optional`. If your
code has a function returning `RadioDefinition?` and writes:

```swift
return .Icom.ic7300()    // ❌ compile error: 'RadioDefinition?' has no member 'Icom'
```

…fully qualify the namespace path:

```swift
return RadioDefinition.Icom.ic7300()    // ✅
```

This bites most often in XPC bridges, settings stores, and
factory functions that look up a radio by string identifier.

---

## 2. New: TCP transport

`ConnectionType` gains a `.tcp(host:port:)` case backed by a new
`TCPSerialTransport` actor (Network.framework `NWConnection`
under the hood). Use it for:

- **Flex 6000-series radios** — SmartSDR exposes Kenwood CAT on
  TCP port 4992.
- **Remote `rigctld` or `RigControlServer`** — drive a radio
  attached to another machine over the network.

The underlying `CATProtocol` doesn't know the bytes come from a
socket instead of a serial port, so any text-based vendor
protocol works unchanged.

```swift
let rig = try RigController(
    radio: .Flex.flex6000,
    connection: .tcp(host: "flex-6400.local", port: 4992)
)
```

For TCP connections the `defaultBaudRate` field is ignored.

---

## 3. New: FlexRadio family

Three definition-only radios under a new `.Flex` namespace and
`.flex` `Manufacturer` case. All three reuse `KenwoodProtocol`
on the wire — Hamlib does the same in `kenwood/flex6xxx.c`.

- `.Flex.flex6000` — Flex 6000-series (6300/6400/6500/6600/6700)
  via SmartSDR's TCP CAT bridge. Pair with
  `ConnectionType.tcp(host:port: 4992)`.
- `.Flex.powerSDR` — PowerSDR / FlexRadio Systems / Apache Labs
  via virtual serial CAT.
- `.Flex.thetis` — TAPR open-source PowerSDR fork.

These are **definition-only**: cross-checked against Hamlib but
not yet exercised against real hardware. Issue reports welcome.

---

## 4. New: targeted serial-port auto-detection

`RadioDiscovery` answers "which serial port is my radio on?"
without scanning every vendor at every baud rate. The caller
tells the library which radio the user has, and discovery
probes ports until one answers correctly.

```swift
// Single radio
guard let port = await RadioDiscovery.detect(.Icom.ic7300()) else {
    print("Couldn't find an IC-7300.")
    return
}
let rig = try RigController(
    radio: .Icom.ic7300(),
    connection: .serial(path: port.portPath, baudRate: port.baudRate)
)

// Multiple candidate radios
let found = await RadioDiscovery.detect([
    .Icom.ic7300(),
    .Yaesu.ftdx10,
])
```

Probes use the radio's `defaultBaudRate` and the appropriate
vendor identify query: `0x19 0x00` to the radio's CI-V address
for Icom; `ID;` for Kenwood/Yaesu/Elecraft/Xiegu/Lab599/Flex.
Ten-Tec is currently skipped (no standard identify across the
Orion/Legacy split). The port enumerator and probe function
are both injectable via `RadioDiscovery.init` so apps can stub
for previews and tests can drive discovery without `/dev/`.

---

## 5. Other changes

- README's Supported Radios section now tags the four
  hardware-verified models (IC-7100, IC-7600, IC-9700, K2)
  inline with **[Hardware]**. Everything else is implicitly
  definition-only per the verification-status table at the top
  of the README.
- `Manufacturer` gains a `.flex` case ("FlexRadio").
- Zero new runtime dependencies. The TCP transport uses
  Network.framework, which is part of the macOS SDK.

---

## Need help?

Open an issue at <https://github.com/jjones9527/SwiftRigControl/issues>
if a migration path isn't obvious from the table above, or if you
hit something this guide didn't cover.

73 de VA3ZTF

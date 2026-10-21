# Radio verification status

Every catalog entry exposes `RadioDefinition.verificationStatus`. A radio is
marked `.hardware` only after frequency, mode, PTT (where applicable), and at
least one read operation have been exercised against the physical radio.

The following six catalog definitions represent the five hardware-validated
radios:

- Elecraft K2
- Icom IC-7100
- Icom IC-7600
- Icom IC-9700
- Kenwood TH-D72
- Kenwood TH-D72A (the North American variant of the same validated radio)

All other catalog entries are explicitly classified as `.definition`: their
protocols and capabilities are mock-tested and generally cross-referenced with
Hamlib or manufacturer documentation, but have not been validated by this
project on real hardware. This includes popular models such as the IC-7300,
FTX-1, Flex 6000 series, TS-890S, TH-D75, ID-52 PLUS, QMX, and Hamgeek uSDX.

`VerificationStatusTests.everyCatalogRadioHasTheExpectedVerificationClassification`
locks this boundary in CI. Adding a radio increases the definition-only count
unless the change also supplies documented hardware-validation evidence.

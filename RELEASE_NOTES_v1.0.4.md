# SwiftRigControl v1.0.4 Release Notes

**Release Date:** January 14, 2026

## 🎉 Major Milestone: Production-Ready Release

SwiftRigControl v1.0.4 represents a major milestone - the project is now **production-ready** and ready for public release with:

- ✅ **Four radios fully verified** with real hardware (IC-7600, IC-7100, IC-9700, Elecraft K2)
- ✅ **Critical K2 bugs fixed** (power control, PTT control, timing issues)
- ✅ **Professional project structure** ready for open source collaboration
- ✅ **Proper licensing** (LGPL v3.0 following Hamlib's model)
- ✅ **GitHub integration** (issue templates, PR templates)

---

## 🔧 Critical Fixes

### Elecraft K2 Implementation

Three critical bugs were identified and fixed in the K2 implementation:

#### 1. Power Control Format Issue ✅ FIXED

**Problem:**
- Setting 5W would read back as 2W
- Setting 10W would show incorrect values
- Power settings not persisting correctly

**Root Cause:**
- K2 uses **direct watts** format: `PC005` = 5 watts
- K3/K4 use **percentage** format: `PC033` = 33% power
- Protocol was incorrectly treating K2 like K3/K4

**Solution:**
- Auto-detect K2 by checking maxPower (≤15W = K2)
- Use direct watts format for K2: `setPower(5)` → `PC005`
- Use percentage format for K3/K4: `setPower(50W @ 100W max)` → `PC050`

**Testing:** Verified with hardware - power control now reads correct values

**See:** [K2_POWER_FIX.md](Documentation/Development/K2/K2_POWER_FIX.md)

---

#### 2. PTT Control Missing ✅ FIXED

**Problem:**
- Calling `rig.isPTTEnabled()` threw error: "PTT query not supported on Elecraft"
- No way to check if K2 was transmitting

**Root Cause:**
- PTT query (`getPTT()`) was not implemented for K2

**Solution:**
- Implemented using **TQ command** for K2 (returns TQ0 = RX, TQ1 = TX)
- Implemented using **IF command** for K3/K4 (includes TX status in response)
- Added to `ElecraftProtocol`: `getTXStatus()` and updated `getPTT()`

**Testing:** Verified with hardware - PTT query fully functional

**See:** [K2_PTT_FIX.md](Documentation/Development/K2/K2_PTT_FIX.md)

---

#### 3. PTT Timing Issues ✅ FIXED

**Problem:**
- Even after implementing TQ query, it returned TQ0 (RX) when radio was actually transmitting
- Sometimes worked, sometimes didn't - race condition

**Root Cause:**
- K2 TX/RX state transition takes **50-100ms** due to:
  - T/R relay switching
  - PA transistor biasing
  - Local oscillator changes
  - RF muting circuits
  - Internal state updates
- Query was happening too quickly after TX command

**Solution:**
- Increased `setPTT()` delay from 50ms → **100ms** for TX/RX state change
- Added **20ms pre-query delay** in `getPTT()` before sending TQ command
- Total timing budget: ~120ms from TX command to verified status

**Testing:**
- Verified with external **watt meter** showing correct RF output
- Tested in **CW mode** (produces carrier without audio requirement)
- 5-second observation test with power meter deflection confirmed

**See:**
- [K2_PTT_TIMING_FIX.md](Documentation/Development/K2/K2_PTT_TIMING_FIX.md)
- [K2_PTT_SSB_AUDIO_REQUIREMENT.md](Documentation/Development/K2/K2_PTT_SSB_AUDIO_REQUIREMENT.md)
- [K2_PTT_5_SECOND_TEST.md](Documentation/Development/K2/K2_PTT_5_SECOND_TEST.md)

---

## ✨ New Features

### LGPL v3.0 License

SwiftRigControl is now licensed under **GNU Lesser General Public License v3.0**, following the same model as [Hamlib](https://hamlib.github.io/).

**What this means for you:**
- ✅ **Use freely** in commercial or open source applications
- ✅ **Link as a library** - your application code remains under your chosen license
- ✅ **Distribute freely** - no restrictions on redistribution
- ⚠️ **Share modifications** - if you modify SwiftRigControl itself, those changes must be shared under LGPL v3.0
- ✅ **Attribution** - minimal requirement to mention you use SwiftRigControl

**Why LGPL v3.0?**
- Aligns with Hamlib (industry standard for ham radio libraries)
- Allows commercial integration (Ham Radio Deluxe, logging apps, etc.)
- Ensures library improvements benefit the entire amateur radio community
- Modern version (2007) vs Hamlib's LGPL v2.1 (1999)

---

### GitHub Integration

Professional issue and PR templates for community contribution:

- **Bug Report Template** - Structured bug reporting with environment details
- **Feature Request Template** - Organized feature proposals
- **Radio Support Request Template** - New radio model requests
- **Pull Request Template** - Code review checklist and testing requirements

Located in `.github/ISSUE_TEMPLATE/` and `.github/PULL_REQUEST_TEMPLATE.md`

---

### K2 Debug Tools

Three specialized debugging tools added to `Examples/Debugging/`:

1. **K2PTTDebug** - Comprehensive PTT testing
   - Tests TX/RX commands with timing analysis
   - 5-second observation windows for watt meter confirmation
   - Tests both TQ and IF query methods
   - Usage: `K2_SERIAL_PORT="/dev/cu.usbserial-XXX" swift run K2PTTDebug`

2. **K2PowerDebug** - QRP power control verification
   - Tests power setting and reading (1W-15W)
   - Verifies correct format (direct watts vs percentage)
   - Usage: `K2_SERIAL_PORT="/dev/cu.usbserial-XXX" swift run K2PowerDebug`

3. **K2NewCommandsTest** - New command verification
   - Tests TQ (transmit query)
   - Tests RC/RD/RU (RIT control)
   - Usage: `K2_SERIAL_PORT="/dev/cu.usbserial-XXX" swift run K2NewCommandsTest`

---

### K2 New Commands Implemented

- **TQ (Transmit Query)** - Returns TQ0 (RX) or TQ1 (TX)
  - Most efficient way to check TX/RX status on K2
  - Used internally by `getPTT()`
- **RC (RIT Clear)** - Clears RIT/XIT offset to zero
- **RD (RIT Down)** - Decreases RIT/XIT offset by 10 Hz
- **RU (RIT Up)** - Increases RIT/XIT offset by 10 Hz

---

## 📁 Project Reorganization

### Root Directory Cleanup

The root directory now contains only essential user-facing files:
- README.md
- CHANGELOG.md
- CONTRIBUTING.md
- ROADMAP.md
- LICENSE
- Package.swift

All development notes (60+ markdown files) moved to organized structure:

```
Documentation/
├── Development/
│   ├── K2/                  # 10 K2 implementation docs (~80 pages)
│   ├── Icom/                # 19 IC-7600/7100/9700 docs
│   ├── Research/            # 6 Hamlib comparison docs
│   ├── Testing/             # 8 test suite docs
│   ├── Sprints/             # 5 sprint summaries
│   └── General/             # 12 misc development docs
└── (user-facing documentation)
```

### Enhanced .gitignore

- Added `*.pdf` exclusion (copyrighted manufacturer manuals)
- Added `*.sh` exclusion (test scripts)
- Added editor directories (.vscode/, .idea/)
- Organized with category comments

### Files Removed from Tracking

- 5 PDF files (~3MB) - copyrighted manufacturer manuals
  - Users should download from manufacturer websites
- Test scripts (test_ic7100_ptt.sh)
- Backup files (*.backup)
- 3 redundant debug tools

---

## ✅ Hardware Verification Complete

Four radios fully tested and verified with real hardware:

### IC-7600 ✅
- All 13 comprehensive tests passing
- Dual receiver operation
- All HF bands (160m-6m)
- Mode control, power, split, RIT/XIT, PTT
- Commit: 5a02fca

### IC-7100 ✅
- All 7 multi-band tests passing
- HF + VHF + UHF testing
- Mode control across all bands
- Power control, split operation, PTT

### IC-9700 ✅
- All 14 tests passing
- 4-state VFO architecture
- VHF/UHF/1.2GHz bands
- Satellite mode operation
- Dual independent receivers
- Cross-band operation

### Elecraft K2 ✅
- All 11 tests passing
- Frequency control (160m-10m including WARC)
- QRP power control (1-15W) - **FIXED**
- PTT control (CW mode tested) - **FIXED**
- RIT/XIT control - **NEW**
- Split operation
- Fine frequency control (10 Hz steps)

---

## 📚 Documentation

### Comprehensive K2 Documentation

10 detailed documents (~80 pages total):

1. **K2_IMPLEMENTATION_REVIEW.md** (17 pages) - Complete command-by-command analysis against KIO2 spec
2. **K2_REVIEW_SUMMARY.md** - Executive summary (A- grade, 90% implementation)
3. **K2_POWER_FIX.md** - Power control format fix details
4. **K2_PTT_FIX.md** - PTT implementation documentation
5. **K2_PTT_TIMING_FIX.md** - TX/RX transition timing analysis
6. **K2_PTT_TROUBLESHOOTING.md** - Comprehensive troubleshooting guide
7. **K2_PTT_SSB_AUDIO_REQUIREMENT.md** - SSB audio requirement discovery
8. **K2_PTT_CW_MODE_TEST.md** - CW mode testing rationale
9. **K2_PTT_5_SECOND_TEST.md** - 5-second observation test guide
10. **K2_PTT_INVESTIGATION.md** - Initial investigation notes

All located in `Documentation/Development/K2/`

---

## 🔍 Technical Details

### K2 Protocol Characteristics Documented

- Does NOT echo SET commands (only echoes QUERY commands)
- Requires 50ms delay between commands (prevents buffer overflow)
- Returns `?;` when busy (transmit, direct frequency entry, scanning)
- Uses direct watts for power control (000-015 for QRP)
- TX/RX transition: 50-100ms hardware delay for relay/PA
- Firmware requirement: 2.01+ (tested with 2.04)

### Build Status

- ✅ Swift 6.2+ compatible
- ✅ Package builds successfully
- ✅ Zero compilation errors
- ✅ All hardware validators functional
- ✅ Professional project structure

---

## 🚀 Migration & Compatibility

### No Breaking Changes

This is a **bugfix and organizational release**. All public APIs remain unchanged.

### For K2 Users

If you were experiencing power control or PTT issues with K2, these are now fixed:
- ✅ Power control reads correct values
- ✅ PTT query works correctly
- ✅ Proper timing for TX/RX state transitions

**No code changes required** on your end - just update to v1.0.4.

### For All Users

The project structure is cleaner but all APIs remain unchanged. If you reference internal documentation files in build scripts, note they've moved to `Documentation/Development/`.

---

## 🎯 What's Next

SwiftRigControl is now production-ready with:
1. ✅ Four radios verified with hardware
2. ✅ Professional structure ready for contributors
3. ✅ Proper licensing (LGPL v3.0)
4. ✅ GitHub templates for community collaboration
5. ✅ Comprehensive documentation

**The project is ready for:**
- Public GitHub release
- Third-party integration
- Mac App Store applications
- Commercial rig control software
- Amateur radio community contributions

---

## 📦 Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/jjones9527/SwiftRigControl.git", from: "1.0.4")
]
```

### Requirements

- macOS 13.0 or later
- Swift 5.9 or later
- Xcode 15.0 or later (for development)

---

## 🙏 Acknowledgments

- Elecraft for KIO2 Programmer's Reference documentation
- Icom for CI-V protocol documentation
- Hamlib project for establishing LGPL as the standard for ham radio libraries
- Amateur radio community for testing and feedback

---

## 📞 Support & Contributing

- **Issues:** https://github.com/jjones9527/SwiftRigControl/issues
- **Documentation:** See README.md and Documentation/ directory
- **Contributing:** See CONTRIBUTING.md
- **License:** GNU Lesser General Public License v3.0 - see LICENSE

---

**73 de VA3ZTF**

Jeremy Jones

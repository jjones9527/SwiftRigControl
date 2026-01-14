---
name: Bug Report
about: Report a bug or unexpected behavior
title: '[BUG] '
labels: bug
assignees: ''
---

## Description
A clear and concise description of the bug.

## Environment
- **macOS Version:** (e.g., macOS 14.0 Sonoma)
- **Swift Version:** (e.g., Swift 5.9)
- **SwiftRigControl Version:** (e.g., 1.2.0)
- **Radio Model:** (e.g., IC-7300, K3, FT-991A)
- **Connection Type:** (Serial / Network)

## Steps to Reproduce
1. Initialize RigController with...
2. Call method...
3. Observe error...

## Expected Behavior
What you expected to happen.

## Actual Behavior
What actually happened.

## Code Sample
```swift
// Minimal code sample that reproduces the issue
let rig = try RigController(
    radio: .icomIC7300,
    connection: .serial(path: "/dev/cu.usbserial-XXX", baudRate: 19200)
)
// ...
```

## Error Messages
```
Paste any error messages or logs here
```

## Additional Context
Add any other context, screenshots, or information about the problem here.

## Hardware Details (if applicable)
- Firmware version
- Interface adapter (e.g., CI-V USB, KIO2, etc.)
- Cable type

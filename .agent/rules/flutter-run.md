---
trigger: always_on
---

# Flutter Verification Rule
Whenever making code changes in a Flutter project, the agent MUST:
- Proactively run 'flutter run' on the available emulator.
- Perform a 'Hot Restart' (R) to verify database/startup initialization.
- Resolve any syntax or runtime errors encountered without bothering the user.
- Only notify the user once the app is confirmed stable and running with valid logs.
- Prefer 'print()' over 'dart:developer.log()' for terminal visibility.
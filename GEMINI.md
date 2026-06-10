# MentorLinks App - Project Instructions

## Architecture & Conventions
- **Framework:** Flutter (latest stable).
- **State Management:** Riverpod (`flutter_riverpod`).
- **Backend:** Firebase (Auth, Firestore).
- **RTC:** Agora (`agora_rtc_engine`).
- **Style:** 
  - Follow official Flutter/Dart linting rules (see `analysis_options.yaml`).
  - Use Material Design 3 (Material Design is enabled in `pubspec.yaml`).
  - **Typography:** `google_fonts` (specifically `Poppins`).
  - **Color Palette:** Primary color is `0xFF333697`.
- **Directory Structure:**
  - `lib/features/`: Feature-based architecture (auth, mentee, mentor).
  - `lib/features/*/logic/`: Business logic and providers.
  - `lib/features/*/presentation/`: UI screens and widgets.
  - `lib/features/*/services/`: External API or service integrations.

## Workflows
- **Code Style:** Run `flutter format .` before committing.
- **Testing:** Add unit tests in `test/` for logic and widget tests for key UI components.
- **Linters:** Ensure `flutter analyze` passes.

## Specialized Instructions
- **Live Sessions:** Agora implementation is located in `live_session_screen.dart` files. Ensure permissions are handled correctly using `permission_handler`.
- **Firebase:** Always check `firebase_core` initialization in `main.dart`.

# flutter_clock_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Windows note (Unicode project path)

If your project path contains non-ASCII characters (for example `Đồng hồ báo thức`), Android build tools may fail when running `flutter run` directly from that path.

Use:

```powershell
.\run_ascii_path.ps1
```

This script maps the project to `X:` and runs Flutter there. You can also pass any Flutter command arguments:

```powershell
run_ascii_path.cmd build apk --debug
run_ascii_path.cmd run -d emulator-5554
```

Use `run_ascii_path.cmd` when passing flags (`--debug`, `--release`, etc.) so arguments are forwarded exactly.

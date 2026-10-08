# Battle Game (Flutter + Flame + Dart server)

Monorepo (pub workspace + Melos). See docs/ for ADRs and conventions.

## Setup
```bash
dart pub global activate fvm && fvm install stable && fvm use stable
dart pub get
dart run melos bootstrap
cd apps/game_client && flutter create . --org com.yourstudio --project-name game_client
```
`flutter create .` only generates the platform folders (android, ios, web...); it keeps the existing lib/.

## Daily commands
```bash
dart run melos run arch
dart run melos run analyze
dart run melos run test
dart run melos run test:client
cd apps/game_client && flutter run --dart-define-from-file=config/dev.json
```
Press F3 in the client to toggle the debug overlay.

## Layout
game_core (pure Dart sim) <- protocol <- game_server / api_server. game_client uses game_core.
Check the latest versions on pub.dev before pinning (flame, melos, very_good_analysis).

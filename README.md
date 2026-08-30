# Tome_client_v1

Flutter UX shell for **Tome: Martial Arts** — character creation through a full
3-fight run, driving the `build_engine` package for every rule via a
`lib/core/engine/` adapter layer, with `flutter_bloc` feature Blocs per phase
and a phase-driven `go_router`.

Requires a local `build_engine` checkout — see `dependency_overrides` in
`pubspec.yaml`.

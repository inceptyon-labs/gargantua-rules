# Contributing

Thanks for helping make Gargantua safer and more useful.

This repository is for rule-only changes: cleanup rules, uninstall remnant rules, command-action rules, schema docs, templates, and validation improvements. App code changes belong in the main [Gargantua app repository](https://github.com/inceptyon-labs/gargantua).

## Rule Checklist

Before opening a pull request:

1. Start from the closest existing YAML file or a template in `docs/templates/`.
2. Use stable, machine-friendly rule IDs.
3. Keep safety conservative when a path can contain user data.
4. Explain why the path is disposable, review-only, or protected.
5. Include realistic path samples in the PR description.
6. Run `Scripts/validate-rules.sh`.
7. Avoid describing a batch as full Mole parity unless the audit inventory has been updated to prove it.

## Cleanup Rules

Cleanup rules live in `rules/cleanup/` and describe files that can be evaluated while an app or tool is still installed.

Use `safe` only for clearly disposable or regenerated data. Use `review` for preferences, local storage, sync state, offline media, or anything with user intent. Use `protected` when removal could affect privileged services or system behavior.

Mole-backed rule batches should stay intentionally selective: port cache, log, derived-artifact, and bounded remnant knowledge first; leave active-file checks, command-backed cleanup, current-version retention, receipt expansion, and external-volume behavior to app features that can model those risks directly.

## Uninstall Remnant Rules

Uninstall remnant rules live in `rules/uninstall/` and describe files that may remain after an app is removed.

Prefer generic placeholders such as `{bundleID}`, `{appName}`, and `{teamID}` over app-specific hardcoding when the same storage family applies broadly.

## Command-Action Rules

Command-action rules live in `rules/command/` and describe tool-owned cleanup that cannot be modeled honestly as path globs, such as `xcrun simctl delete unavailable`, `pnpm store prune`, or Go cache cleanup.

Use `developer_tool_command` for routine tool cleanups. Use `advanced_command_action` for high-consequence commands that may force large re-downloads, break offline work, or affect rollback semantics. Advanced command rules must be `review`, include `consequence`, include `regenerate_command`, declare non-protected `affected_roots`, and set `preconditions.timeout_seconds`.

Command rules are audited as command evidence in the app: the executor records the tool version, exact arguments, exit code, and `kind: command`. Keep the YAML boring and explicit; do not rely on shell expansion, pipes, or implicit working directories.

## App Packs

App packs live in `rules/uninstall/app_packs/` and capture remnants for individual apps where their on-disk layout is idiosyncratic enough that generic placeholders miss real evidence (Docker Desktop, Xcode + helpers, Android Studio + SDK, JetBrains Toolbox + IDEs, VS Code / Cursor / Zed, etc.).

Packs reuse the existing remnant-rule schema. Every rule in a pack MUST scope itself with `applies_to.bundle_ids` so the rule only fires for the named app. The pack file itself is one YAML per app (or one per closely-related cohort, like the VS Code / Cursor / Zed Electron-editor family).

### Pack contract

Each pack file MUST include a header comment that documents:

1. **Bundle IDs** — every bundle ID the pack scopes to, including beta / preview / OSS variants.
2. **Trust Layer matrix** — which paths are `safe`, `review`, and `protected`, and the rationale for each bucket.
3. **Do-not-touch carve-outs** — explicit list of paths the pack deliberately excludes or marks `protected`, and *why* (credentials, signing identities, hand-authored content, account-bound sync state, etc.).
4. **Evidence** — at least one realistic path captured on a real install of the app, with the date captured. Reviewers use this to sanity-check that the pack was authored against actual evidence rather than guessed paths.

### Trust Layer defaults for app packs

- `safe` — disposable caches, logs, GPU/shader caches, language-server caches, derived artifacts that regenerate on next launch.
- `review` — settings directories, workspace state, simulator/emulator images, Toolbox-managed runtimes, anything that holds project-bound or version-bound state.
- `protected` — credentials, signing identities (debug keystore, provisioning profiles, adb keys), license activation state, account-bound Settings Sync directories, and hand-authored configuration the user is unlikely to want auto-removed.

### Working alongside `CommandActionRule`

Some app cleanups are better expressed as commands than as path globs (e.g. `xcrun simctl delete unavailable`, Toolbox version pruning). Where a pack lists a path that a command rule can address more precisely, mark the path `review` and reference the command rule in the pack header. This keeps the path visible as evidence without the pack racing the command rule.

### Authoring checklist

- Start from `docs/templates/remnant-rule.yaml` and the existing packs in `rules/uninstall/app_packs/`.
- Capture real paths on a development machine where the app is installed; do not guess.
- Mark every credentials, signing-identity, license-state, and hand-authored-config path `protected`.
- Treat common project roots, clipboard/history stores, and user-authored automation as `protected` or explicitly excluded.
- Use `exclude` to carve out protected children when a parent directory is otherwise reviewable (e.g. `~/.docker` reviewable, but `~/.docker/config.json` excluded and surfaced separately as `protected`).
- Document the carve-outs in the file header so reviewers can verify them without diffing.
- Run `Scripts/validate-rules.sh uninstall` and include realistic path samples in the PR description.

## Validation

Run:

```bash
Scripts/validate-rules.sh
```

The validator checks YAML structure, required fields, safety values, confidence ranges, non-empty paths, command affected roots, and duplicate rule IDs.
It also checks optional guard, filter, profile override, app-scope, and command-action field shapes used by the current app snapshot.

## App Snapshot Sync

Gargantua imports reviewed snapshots from this repository into the app bundle. If a rule PR adds a new category, schema field, or behavior that requires UI/profile support, call that out in the PR so the app snapshot import can include the matching app change.

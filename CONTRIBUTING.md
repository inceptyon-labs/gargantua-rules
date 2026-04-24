# Contributing

Thanks for helping make Gargantua safer and more useful.

This repository is for rule-only changes: cleanup rules, uninstall remnant rules, schema docs, templates, and validation improvements. App code changes belong in the main [Gargantua app repository](https://github.com/inceptyon-labs/gargantua).

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

## Validation

Run:

```bash
Scripts/validate-rules.sh
```

The validator checks YAML structure, required fields, safety values, confidence ranges, non-empty paths, and duplicate rule IDs.
It also checks optional guard, filter, profile override, and app-scope field shapes used by the current app snapshot.

## App Snapshot Sync

Gargantua imports reviewed snapshots from this repository into the app bundle. If a rule PR adds a new category, schema field, or behavior that requires UI/profile support, call that out in the PR so the app snapshot import can include the matching app change.

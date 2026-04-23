# Gargantua Rules

Community-maintained cleanup and uninstall rules for [Gargantua](https://github.com/inceptyon-labs/gargantua).

Gargantua does not load mutable remote rules at runtime. The app imports reviewed snapshots from this repository into its bundled resources so every release keeps deterministic safety behavior.

## Current Inventory

- Cleanup rules: 19 files / 83 rules
- Uninstall remnant rules: 2 files / 12 rules

## Repository Layout

- `rules/cleanup/`
  YAML cleanup rules used while an app or tool is still installed.
- `rules/uninstall/`
  YAML remnant rules used after an app has been removed.
- `docs/schema.md`
  Practical schema guide for cleanup and uninstall rules.
- `docs/templates/`
  Copyable starting points for new rule files.
- `Scripts/validate-rules.sh`
  Standalone validation for rule-only pull requests.

## Contributing Rules

1. Pick the closest existing rule file and match its style.
2. Keep `safety` conservative when a path may contain user data.
3. Add enough `explanation` text for reviewers to understand the risk.
4. Run `Scripts/validate-rules.sh` before opening a pull request.
5. Mention any app-side sync impact if you add a new category or schema field.

For more detail, see [CONTRIBUTING.md](CONTRIBUTING.md) and [docs/schema.md](docs/schema.md).

## Safety Model

- `safe`: disposable caches, logs, derived artifacts, or rebuildable state.
- `review`: preferences, local storage, sync state, offline media, containers, or anything that may carry user data.
- `protected`: launch daemons, privileged helpers, boot/system paths, or anything that can affect system integrity.

When in doubt, choose `review`.

## Validation

Run all validation:

```bash
Scripts/validate-rules.sh
```

Scope validation when iterating:

```bash
Scripts/validate-rules.sh cleanup
Scripts/validate-rules.sh uninstall
```

## Release Flow

Rule changes merge here first. Gargantua app releases then import a reviewed snapshot into `Sources/GargantuaCore/Resources/` in the app repository. This keeps community rule work decoupled from app releases without making installed apps depend on live network rule updates.

## License

MIT. See [LICENSE](LICENSE).

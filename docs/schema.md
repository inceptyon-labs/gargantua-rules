# Rule Schema

This is a practical schema guide for contributors. The Gargantua app imports these YAML files into its bundled runtime resources after review.

## Cleanup Rule Shape

Cleanup files live under `rules/cleanup/` and use this top-level key:

```yaml
rules:
```

Common fields:

- `id`: stable unique identifier.
- `name`: human-readable name.
- `paths`: one or more absolute or `~`-relative glob paths.
- `pattern`: optional filename filter inside a matched directory.
- `exclude`: optional glob exclusions.
- `skip_if_process_running`: optional bundle IDs or process/app names that skip the rule while running.
- `presence_guards`: optional candidate-relative or absolute paths that skip a match when present.
- `content_guards`: optional candidate-relative or absolute files whose contents can skip a match.
- `match_filters`: optional conditions that must match before an item is surfaced, such as `mtime age > 30d`.
- `safety`: `safe`, `review`, or `protected`.
- `confidence`: integer from `0` to `100`.
- `explanation`: one-line rationale shown in the app.
- `source.name`: app or subsystem name.
- `source.bundle_id`: optional bundle identifier.
- `source.verify_signature`: optional boolean.
- `regenerates`: boolean.
- `regenerate_command`: optional command hint.
- `category`: scan category used by profiles and grouping.
- `tags`: optional tags.
- `safety_overrides`: optional profile-aware reclassification rules.

Example:

```yaml
rules:
  - id: example_cache
    name: Example Cache
    paths:
      - "~/Library/Caches/com.example.app"
    safety: safe
    confidence: 98
    explanation: "Disposable cache files regenerated automatically."
    source:
      name: Example App
      bundle_id: com.example.app
      verify_signature: true
    regenerates: true
    category: app_cache
    tags: [app, example, cache]
```

Guard examples:

```yaml
skip_if_process_running:
  - com.example.app
presence_guards:
  - path: "Offline Media"
    scope: candidate
content_guards:
  - path: "metadata.json"
    contains: "do-not-clean"
match_filters:
  - "mtime age > 30d"
```

Guard `scope` may be `candidate` (default, relative to the matched item) or `absolute`.
Safety override conditions currently support age expressions such as `age > 30d`; match filters also support `mtime` and `atime` prefixes.

## Remnant Rule Shape

Uninstall remnant files live under `rules/uninstall/` and use this top-level key:

```yaml
remnant_rules:
```

Common fields:

- `id`: stable unique identifier.
- `name`: human-readable name.
- `category`: remnant category used by the Smart Uninstaller.
- `path_templates`: one or more templates using `{bundleID}`, `{appName}`, or `{teamID}`.
- `pattern`: optional filename filter inside a matched directory.
- `exclude`: optional glob exclusions.
- `safety`: optional explicit `safe`, `review`, or `protected`; otherwise the app uses the category default.
- `confidence`: integer from `0` to `100`.
- `explanation`: one-line rationale shown in the app.
- `source.name`: app or subsystem name.
- `source.bundle_id`: optional bundle identifier.
- `source.verify_signature`: optional boolean.
- `applies_to.bundle_ids`: optional allow-list.
- `applies_to.exclude_bundle_ids`: optional deny-list.
- `regenerates`: boolean.
- `tags`: optional tags.

Example:

```yaml
remnant_rules:
  - id: example_support
    name: Example Support Files
    category: support_files
    path_templates:
      - "~/Library/Application Support/{appName}"
    confidence: 90
    explanation: App-written support data left behind after uninstall.
    source:
      name: "{appName}"
    regenerates: false
    tags: [generic, support]
```

## Safety Heuristics

- `safe`: disposable caches, logs, derived artifacts, rebuildable state.
- `review`: local storage, sync state, preferences, offline media, containers.
- `protected`: launch daemons, privileged helpers, boot/system paths, or similarly sensitive system-impacting items.

## Naming Guidelines

- Keep `id` stable and machine-friendly.
- Prefix app-specific IDs with the app name, such as `slack_cache`.
- Prefer one rule per meaningful storage family instead of one giant catch-all rule.
- Avoid introducing new categories unless the app needs different profile behavior or UI grouping.

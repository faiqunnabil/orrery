# Translations

Collects every user-facing message into `godot/i18n/messages.pot` and keeps each language catalog, such as `godot/i18n/id.po`, in step with it.

## Requirements

- Python 3.10 or newer. The script uses only the standard library.

## Usage

From the repository root:

```
python tools/i18n/extract_messages.py          # update messages.pot and every .po file
python tools/i18n/extract_messages.py --check  # also fail if a message is untranslated or its placeholders differ
```

Messages come from two places:

| Source | What is collected |
|---|---|
| `godot/**/*.gd` | String literals that read as interface text, and every literal passed to `tr()` or `Locale.t()` |
| `godot/data/*.json` | Body names and types, info texts, tours, quizzes, sandbox presets, and credit titles |

The English text is the message id, so a `.po` file only needs a `msgstr` for each entry. Existing translations are kept when the catalogs are rewritten, and messages that no longer exist in the code are dropped. Placeholders such as `%s`, `%d`, and `%.2f` must appear in the same order in the translation.

To add a language, add its code to `LANGUAGES` in the script and to `Locale.LANGUAGES` in `godot/core/locale.gd`, run the script, fill in the new `.po` file, and register it under `locale/translations` in `godot/project.godot`.

The voice-over exists in English only, so narration is turned off for other languages while captions follow the chosen language.

import argparse
import json
import re
import sys
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
GODOT = REPOSITORY_ROOT / "godot"
LANGUAGES = ["id"]
STRING_LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')
SKIPPED_LINE = re.compile(
    r"print\(|push_error|push_warning|load\(|preload\(|get_node\(|has_method|set_shader_parameter|get_shader_parameter|"
    r"theme_type_variation|is_action|action_|StringName|set_meta|get_meta|Performance\.|connect\(|emit_signal|"
    r"set_value\(|get_value\(|ProjectSettings|OS\.get_environment|\.has\(|\[\"[a-z_]+\"\]|const [A-Z_]+_PATH|"
    r"set_stylebox|set_color|set_font|set_constant|set_type_variation|add_theme_|get_theme_|OrreryTheme\.icon\("
)
TRANSLATION_CALL = re.compile(r'(?:\btr|Locale\.t)\(\s*"((?:[^"\\]|\\.)*)"')
IDENTIFIER = re.compile(r"^[a-z0-9_.:/%-]+$")
CAMEL_TYPE = re.compile(r"^[A-Z][a-z0-9]+(?:[A-Z][a-z0-9]+)+$")
WORD = re.compile(r"[A-Za-z]{2,}")
JSON_KEYS = {
    "data/body_info.json": {"type", "summary", "summary_scientist", "facts", "facts_scientist", "explorer", "scientist"},
    "data/tours.json": {"title", "summary", "text", "text_scientist"},
    "data/quizzes.json": {"question", "options", "explanation", "title"},
    "data/bodies.json": {"name"},
    "data/sandbox_presets.json": {"name", "description"},
    "data/credits.json": {"title", "notice", "role", "name"},
    "data/challenges.json": {"title", "goal", "hint", "name"},
}
CREDIT_ENTRY_KEYS = {"author", "license", "url", "text"}
PLACEHOLDER = re.compile(r"%[0-9.]*[dsf]")
CONCATENATION = re.compile(r'"\s*\n?\s*\+\s*"')
UNIT_WORDS = {"km", "kg", "AU", "deg", "ms", "FPS", "MB", "UTC", "RK", "VRAM", "m2", "s"}
IGNORED = {"Button", "Dummy", "Wayland", "ABCDEFGH", "Verlet"}


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extract user-facing text into i18n/messages.pot and update each .po file.")
    parser.add_argument("--check", action="store_true", help="Exit with an error if any message lacks a translation")
    return parser.parse_args()


def is_message(text: str) -> bool:
    words = WORD.findall(re.sub(r"%[0-9.]*[dsf]", "", text))
    if not words or all(word in UNIT_WORDS for word in words):
        return False
    if text in IGNORED or text.startswith("#") or "{" in text or not re.search("[a-z]", text):
        return False
    if text.startswith(("res://", "user://", "http")) or IDENTIFIER.match(text) or CAMEL_TYPE.match(text):
        return False
    if "/" in text and " " not in text and not re.match(r"^\d+ \w+/s$", text):
        return False
    return True


def unescape(text: str) -> str:
    return text.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")


def from_scripts(messages: dict[str, set[str]]) -> None:
    for path in sorted(GODOT.rglob("*.gd")):
        relative = path.relative_to(GODOT).as_posix()
        source = CONCATENATION.sub("", path.read_text(encoding="utf-8"))
        for number, line in enumerate(source.splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            literals = TRANSLATION_CALL if SKIPPED_LINE.search(line) else STRING_LITERAL
            for match in literals.finditer(line):
                text = unescape(match.group(1))
                if is_message(text):
                    messages.setdefault(text, set()).add(f"{relative}:{number}")


def walk(value, keys: set[str], inside: bool, sink) -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            if key in CREDIT_ENTRY_KEYS and "author" in value:
                continue
            walk(child, keys, key in keys, sink)
    elif isinstance(value, list):
        for child in value:
            walk(child, keys, inside, sink)
    elif isinstance(value, str) and inside and WORD.search(value):
        sink(value)


def from_data(messages: dict[str, set[str]]) -> None:
    for relative, keys in JSON_KEYS.items():
        path = GODOT / relative
        data = json.loads(path.read_text(encoding="utf-8"))
        walk(data, keys, False, lambda text, source=relative: messages.setdefault(text, set()).add(source))


def escape(text: str) -> str:
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def po_unescape(text: str) -> str:
    return text.replace("\\n", "\n").replace('\\"', '"').replace("\\\\", "\\")


def read_po(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    entries: dict[str, str] = {}
    current_id = None
    field = None
    buffers = {"msgid": "", "msgstr": ""}
    for line in path.read_text(encoding="utf-8").splitlines() + [""]:
        if line.startswith("msgid "):
            if current_id is not None:
                entries[current_id] = buffers["msgstr"]
            field = "msgid"
            buffers = {"msgid": po_unescape(line[7:-1]), "msgstr": ""}
            current_id = None
        elif line.startswith("msgstr "):
            field = "msgstr"
            buffers["msgstr"] = po_unescape(line[8:-1])
            current_id = buffers["msgid"]
        elif line.startswith('"') and field is not None:
            buffers[field] += po_unescape(line[1:-1])
            if field == "msgid":
                current_id = None
            else:
                current_id = buffers["msgid"]
        elif line.strip() == "" and current_id is not None:
            entries[current_id] = buffers["msgstr"]
            current_id = None
            field = None
    entries.pop("", None)
    return entries


def write_catalog(path: Path, messages: dict[str, set[str]], translations: dict[str, str] | None, language: str = "") -> None:
    lines = [
        'msgid ""',
        'msgstr ""',
        '"Project-Id-Version: Orrery\\n"',
        '"MIME-Version: 1.0\\n"',
        '"Content-Type: text/plain; charset=UTF-8\\n"',
        '"Content-Transfer-Encoding: 8-bit\\n"',
    ]
    if language:
        lines.append(f'"Language: {language}\\n"')
    for text in sorted(messages, key=lambda item: (sorted(messages[item])[0], item)):
        lines.append("")
        lines.append("#: " + " ".join(sorted(messages[text])[:3]))
        lines.append(f'msgid "{escape(text)}"')
        translated = "" if translations is None else translations.get(text, "")
        lines.append(f'msgstr "{escape(translated)}"')
    path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def main() -> int:
    arguments = parse_arguments()
    messages: dict[str, set[str]] = {}
    from_scripts(messages)
    from_data(messages)
    output = GODOT / "i18n"
    output.mkdir(exist_ok=True)
    write_catalog(output / "messages.pot", messages, None)
    problems = 0
    for language in LANGUAGES:
        po_path = output / f"{language}.po"
        translations = read_po(po_path)
        write_catalog(po_path, messages, translations, language)
        missing = [text for text in messages if not translations.get(text)]
        mismatched = [
            text for text in messages
            if translations.get(text) and PLACEHOLDER.findall(text) != PLACEHOLDER.findall(translations[text])
        ]
        problems += len(missing) + len(mismatched)
        print(f"{language}: {len(messages) - len(missing)} of {len(messages)} messages translated")
        for text in mismatched:
            print(f"{language}: placeholders differ in {text!r}")
    if arguments.check and problems:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

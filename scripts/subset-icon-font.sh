#!/bin/sh
# Урезает шрифт значков до тех иконок, которые оболочка действительно рисует.
#
# Зачем. Material Symbols Rounded — вариативный шрифт на 6182 глифа и 14 МБ.
# Qt отображает его в память по мере использования, и в долгой сессии это
# 17 МБ резидентно. Оболочка рисует около четырёхсот иконок, остальное лежит
# мёртвым грузом.
#
# Как. Имена иконок собираются из самого проекта: строковые литералы вида
# "wifi", имена из config/*.json, из C++ (погода отдаёт sunny, rainy, foggy),
# плюс развёрнутые начала имён для тех, что собираются в коде из частей
# (battery_android_ + цифра).
#
# Главное, что поменялось. Раньше имена иконок сверялись с именами ГЛИФОВ.
# Это неверно: Qt подставляет иконку, прогоняя строку через таблицу лигатур
# GSUB (rlig), и у части иконок имя строки не совпадает с именем глифа.
# Например, "smartphone" рисует глиф mobile, "draft" — note, "clear" — close,
# "mode_night" — brightness_2, а "battery_android_5" — глиф
# battery_android_digit_five. Из-за этого такие иконки молча пропадали.
# Теперь карта «строка -> глиф» строится из самой таблицы GSUB, а цифры и
# подчёркивания в именах раскодируются через cmap (глифы digit_one,
# underscore). Поэтому в шрифт попадает ровно тот глиф, который нужен.
#
# Важно про features: Material Symbols подставляет иконки через `rlig`.
# Если оставить только `liga`, из шрифта пропадут все подстановки и вместо
# иконок будут видны их названия буквами. Тег `rclt` в этом файле пустой
# (ни одной подстановки), поэтому его отсутствие в результате — норма, а не
# потеря: проверяем наличие и непустоту именно `rlig`.
#
# Полный шрифт хранится в ~/.local/opt/material-symbols и служит источником
# для пересборки. Именно вне каталога шрифтов: fontconfig ищет по имени
# семейства, и две версии с одним именем спорят между собой.
#
# Использование:
#   scripts/subset-icon-font.sh            пересобрать и поставить
#   scripts/subset-icon-font.sh --restore  вернуть полный шрифт
#   scripts/subset-icon-font.sh --dry-run  посчитать, ничего не меняя
#
# Настройка. ICON_FONT_EXTRA_PREFIXES — через запятую начала имён, которые
# нужно оставить целиком, сверх найденных в коде. Нужны только для имён,
# собираемых вне дерева проекта (темы иконок, имена файлов).

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
font_dir="$HOME/.local/share/fonts/material-symbols"
installed="$font_dir/material-symbols-rounded.ttf"
# Полный шрифт держим ВНЕ каталога шрифтов. Если положить его рядом,
# fontconfig увидит два файла с одним именем семейства «Material Symbols
# Rounded» и выберет полный — урезанный окажется бесполезен. Я на это
# наступил: экономии не было, пока копия лежала в font_dir.
full="$HOME/.local/opt/material-symbols/material-symbols-rounded-full.ttf"
venv="$HOME/.local/opt/fonttools-venv"
mode=${1:-}

[ -f "$installed" ] || { echo "Не нашёл шрифт: $installed" >&2; exit 1; }

if [ "$mode" = "--restore" ]; then
    [ -f "$full" ] || { echo "Полного шрифта нет: $full" >&2; exit 1; }
    cp -f "$full" "$installed"
    fc-cache -f "$font_dir" >/dev/null
    echo "Вернул полный шрифт. Перезапустить оболочку: systemctl --user restart my-shell.service"
    exit 0
fi

if [ ! -x "$venv/bin/pyftsubset" ]; then
    echo "Ставлю fonttools в $venv"
    python3 -m venv "$venv"
    "$venv/bin/pip" install -q fonttools brotli
fi

mkdir -p "$(dirname "$full")"

# Источником всегда служит $full. Если его ещё нет, им становится
# установленный шрифт — но только после проверки, что он действительно
# полный. Без этой проверки повторный запуск взял бы за источник уже
# урезанный файл и стёр бы всё остальное: я так и потерял оригинал.
if [ ! -f "$full" ]; then
    if "$venv/bin/python" - "$installed" <<'PY'
import sys
from fontTools.ttLib import TTFont
font = TTFont(sys.argv[1])
order = font.getGlyphOrder()
full_enough = len(order) > 3000
named = any(not n.startswith('glyph') for n in order[3:20])
sys.exit(0 if (full_enough and named) else 1)
PY
    then
        cp "$installed" "$full"
        echo "Сохранил полный шрифт как источник: $full"
    else
        echo "Установленный шрифт уже урезан, а источника нет: $full" >&2
        echo "Положите туда полный Material Symbols Rounded и запустите снова." >&2
        exit 1
    fi
fi

# Копия из прошлых версий скрипта лежала в каталоге шрифтов, и fontconfig
# выбирал её вместо урезанной — экономии не было. Убираем, но только когда
# источник уже на месте.
stale="$font_dir/material-symbols-rounded-full.ttf"
if [ -f "$stale" ] && [ -f "$full" ]; then
    rm -f "$stale"
    echo "Убрал лишнюю копию из каталога шрифтов: $stale"
fi

glyphs=$(mktemp)
labels=$(mktemp)
trap 'rm -f "$glyphs" "$glyphs.ttf" "$labels"' EXIT

"$venv/bin/python" - "$root" "$full" "$glyphs" "$labels" <<'PYEOF'
import json, os, pathlib, re, sys
from fontTools.ttLib import TTFont

root, full_font, out_glyphs, out_labels = (pathlib.Path(sys.argv[1]), sys.argv[2],
                                           pathlib.Path(sys.argv[3]), pathlib.Path(sys.argv[4]))
font = TTFont(full_font)
available = set(font.getGlyphOrder())


def glyph_characters(font):
    """Имя глифа -> ASCII-символ, которым он набирается. Шрифт отображает и
    'a', и 'A' в один глиф, поэтому предпочитаем строчную букву: имена иконок
    записаны строчными, а сопоставление зависит от регистра."""
    chars = {}
    for table in font['cmap'].tables:
        for code, name in table.cmap.items():
            if not 0x20 <= code <= 0x7E:
                continue
            char = chr(code)
            known = chars.get(name)
            if known is None or (known.isupper() and not char.isupper()):
                chars[name] = char
    return chars


chars = glyph_characters(font)


def ligature_map(font):
    """Строка-имя -> глиф, который она рисует. Qt подставляет иконку именно
    так, поэтому авторитетна строка лигатуры, а не имя глифа."""
    result = {}
    for lookup in font['GSUB'].table.LookupList.Lookup:
        for sub in lookup.SubTable:
            # Подстановки лежат в extension-обёртке (тип 7); без её разворота
            # таблица выглядит пустой.
            inner = getattr(sub, 'ExtSubTable', None) or sub
            ligatures = getattr(inner, 'ligatures', None)
            if not ligatures:
                continue
            for first, entries in ligatures.items():
                for entry in entries:
                    parts = [first, *entry.Component]
                    if all(part in chars for part in parts):
                        result.setdefault(''.join(chars[p] for p in parts), entry.LigGlyph)
    return result


ligatures = ligature_map(font)
if not ligatures:
    sys.exit('не разобрал таблицу лигатур: похоже, это не Material Symbols')

SOURCE_SUFFIXES = ('*.qml', '*.js', '*.mjs', '*.cpp', '*.cc', '*.h', '*.hh')
SKIP_DIRS = {'.git', 'build', 'node_modules', '__pycache__'}
string_literal = re.compile(r'"([^"\n]{1,64})"|\'([^\'\n]{1,64})\'|`([^`\n]{1,64})`')
concat_stem = re.compile(r'"([A-Za-z_][A-Za-z0-9_]*)"\s*\+')


def strip_comments(text):
    """Убирает // и /* */, не трогая строковые литералы. Без этого имена
    иконок из комментариев попадали в шрифт."""
    out, i, n, quote = [], 0, len(text), ''
    while i < n:
        ch = text[i]
        if quote:
            if ch == '\\' and i + 1 < n:
                out.append(ch); out.append(text[i + 1]); i += 2; continue
            if ch == quote:
                quote = ''
            out.append(ch); i += 1; continue
        if ch in '"\'`':
            quote = ch; out.append(ch); i += 1; continue
        if ch == '/' and i + 1 < n and text[i + 1] == '/':
            while i < n and text[i] != '\n':
                i += 1
            continue
        if ch == '/' and i + 1 < n and text[i + 1] == '*':
            i += 2
            while i + 1 < n and not (text[i] == '*' and text[i + 1] == '/'):
                i += 1
            i += 2
            continue
        out.append(ch); i += 1
    return ''.join(out)


def sources():
    for suffix in SOURCE_SUFFIXES:
        for path in root.rglob(suffix):
            if SKIP_DIRS & set(path.parts):
                continue
            yield path, strip_comments(path.read_text(encoding='utf-8', errors='ignore'))


strings, stems = set(), set()
for path, text in sources():
    # Любой литерал, совпавший со строкой лигатуры. Контекст не нужен: имена
    # вроде "label" или "route", совпадающие с чужими полями, отсеиваются
    # сами, потому что их нет среди строк лигатур.
    for groups in string_literal.findall(text):
        for value in groups:
            if value in ligatures:
                strings.add(value)
    # Начала имён, собираемых конкатенацией: "battery_android_" + цифра.
    for stem in concat_stem.findall(text):
        hit = {s for s in ligatures if s.startswith(stem)}
        if hit:
            strings |= hit

# Имена из настроек: плитки, карточки, маршруты, действия Niri.
icon_key = re.compile(r'(^|[_-])icon([_-]|$)|symbol|leading|trailing', re.I)
def collect(node, found):
    if isinstance(node, dict):
        for key, value in node.items():
            if isinstance(value, str) and icon_key.search(key) and value in ligatures:
                found.add(value)
            collect(value, found)
    elif isinstance(node, list):
        for value in node:
            collect(value, found)
for path in root.rglob('*.json'):
    if SKIP_DIRS & set(path.parts):
        continue
    try:
        collect(json.loads(path.read_text(encoding='utf-8')), strings)
    except (ValueError, OSError):
        continue

# Страховка для имён, собираемых вне дерева проекта. По умолчанию узкая: всё,
# что есть в коде, уже найдено выше, а широкие начала вроде 'arrow' или
# 'folder' добавляли сотни неиспользуемых глифов.
prefixes = tuple(p for p in os.environ.get(
    'ICON_FONT_EXTRA_PREFIXES',
    'battery_,network_wifi,signal_wifi,volume_,bluetooth,brightness_,mic,'
    'notifications,cloud,weather_'
).split(',') if p)
by_prefix = {s for s in ligatures if s.startswith(prefixes)}

from_code = strings | stems
keep_strings = from_code | by_prefix
keep_glyphs = {ligatures[s] for s in keep_strings}

# Иконка есть в коде, но её нет в шрифте: опечатка или имя из другого набора.
# Молча рисовалась бы буквами, поэтому сообщаем.
strict = re.compile(r'(?:iconName|materialSymbol|secondaryMaterialSymbol|symbol|icon)'
                    r'\s*[:=]\s*"([a-z][a-z0-9_]{2,40})"')
unknown = set()
for path, text in sources():
    for candidate in strict.findall(text):
        if candidate not in ligatures:
            unknown.add(candidate)

renamed = {s: ligatures[s] for s in from_code if ligatures[s] != s}
out_glyphs.write_text('\n'.join(sorted(keep_glyphs)))
out_labels.write_text('\n'.join(sorted(keep_strings)))

print('  имён из кода и данных: %d' % len(from_code))
print('  из развёрнутых начал: %d' % len(by_prefix - from_code))
print('  глифов оставляем: %d из %d' % (len(keep_glyphs), len(available)))
if renamed:
    pairs = ', '.join('%s->%s' % (s, g) for s, g in sorted(renamed.items()))
    print('  имя строки не совпадает с глифом (раньше терялись): %s' % pairs)
if unknown:
    print('  нет в шрифте (опечатка или чужое имя): %s' % ', '.join(sorted(unknown)))
PYEOF

if [ "$mode" = "--dry-run" ]; then
    echo "Ничего не меняю (--dry-run)."
    exit 0
fi

# rlig обязателен: именно им подставляются иконки. rclt в этом шрифте пуст.
"$venv/bin/pyftsubset" "$full" --output-file="$glyphs.ttf" \
    --glyphs-file="$glyphs" --unicodes=U+0020-007E \
    --layout-features=rlig,rclt,liga,calt,ccmp --no-layout-closure \
    --name-IDs='*' --recalc-bounds

"$venv/bin/python" - "$glyphs.ttf" "$labels" <<'PYEOF'
import pathlib, sys
from fontTools.ttLib import TTFont

font = TTFont(sys.argv[1])
want = {s for s in pathlib.Path(sys.argv[2]).read_text().split('\n') if s}

# Проверяем по таблице лигатур самого результата: имя должно разрешаться в
# живой глиф. Проверка по именам глифов не годится — pyftsubset их теряет.
chars = {}
for table in font['cmap'].tables:
    for code, name in table.cmap.items():
        if 0x20 <= code <= 0x7E:
            char = chr(code)
            known = chars.get(name)
            if known is None or (known.isupper() and not char.isupper()):
                chars[name] = char

gsub = font['GSUB'].table
features = {r.FeatureTag: list(r.Feature.LookupListIndex) for r in gsub.FeatureList.FeatureRecord}
assert features.get('rlig'), 'потерялись подстановки: иконки будут видны буквами (%s)' % features

have, rules = set(), 0
for lookup in gsub.LookupList.Lookup:
    for sub in lookup.SubTable:
        inner = getattr(sub, 'ExtSubTable', None) or sub
        ligatures = getattr(inner, 'ligatures', None)
        if not ligatures:
            continue
        for first, entries in ligatures.items():
            for entry in entries:
                rules += 1
                parts = [first, *entry.Component]
                if all(part in chars for part in parts):
                    have.add(''.join(chars[p] for p in parts))

lost = sorted(want - have)
assert not lost, 'иконки не разрешаются после урезания: %s' % lost[:12]
assert rules, 'в результате не осталось ни одной подстановки'

axes = [a.axisTag for a in font['fvar'].axes]
assert 'FILL' in axes and 'opsz' in axes, 'потерялись оси: %s' % axes

empty = [t for t in ('rlig', 'rclt') if t not in features]
print('  проверка: подстановок %d, иконок разрешается %d из %d, оси %s'
      % (rules, len(want & have), len(want), axes))
if empty:
    print('  замечание: пустых тегов нет в результате: %s (для rclt это нормально)'
          % ', '.join(empty))
PYEOF

cp -f "$glyphs.ttf" "$installed"
fc-cache -f "$font_dir" >/dev/null
printf 'Готово: %.2f МБ вместо %.2f МБ\n' \
    "$(stat -c %s "$installed" | awk '{print $1/1048576}')" \
    "$(stat -c %s "$full" | awk '{print $1/1048576}')"
echo "Перезапустить оболочку: systemctl --user restart my-shell.service"
.pragma library

// Код флага по имени раскладки из niri («English (US)», «Russian»…).
// Имена — как в `niri msg keyboard-layouts` (берутся из xkb).
// Добавить язык: строку в known и, если нужен рисунок, флаг в LayoutFlag.qml.
const known = [
    [/english\s*\((us|usa)\b/i, "us"],
    [/english\s*\((uk|gb)\b/i, "gb"],
    [/^english\b/i, "us"],
    [/^russian\b/i, "ru"],
    [/^ukrainian\b/i, "ua"],
    [/^belarusian\b/i, "by"],
    [/^kazakh\b/i, "kz"],
    [/^german\b/i, "de"],
    [/^french\b/i, "fr"],
    [/^spanish\b/i, "es"],
    [/^italian\b/i, "it"],
    [/^polish\b/i, "pl"]
];

function codeFor(name) {
    const value = String(name || "").trim();
    for (let index = 0; index < known.length; index += 1) {
        if (known[index][0].test(value))
            return known[index][1];
    }
    return value.slice(0, 2).toLowerCase();
}

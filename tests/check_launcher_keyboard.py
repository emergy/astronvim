"""Проверка доступности жестов и симметрии рабочих раскладок Launcher."""
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1] / "nix/launcher"
latin = ET.parse(ROOT / "keyboard-layout.xml").getroot()
russian = ET.parse(ROOT / "keyboard-layout-ru.xml").getroot()
keys = lambda layout: {key.get("c"): key for key in layout.iter("key")}
en, ru = keys(latin), keys(russian)
pairs = dict(zip("qwertyuiopasdfghjklzxcvbnm", "йцукенгшщзфывапролдячсмить"))
slots = ("nw", "ne", "sw", "se", "n", "s", "w", "e")
for source, target in pairs.items():
    if target in ("т", "ь", "д"):
        continue
    for slot in slots:
        if (source, slot) == ("t", "nw"):
            assert ru[target].get(slot) == "ё"
        else:
            assert en[source].get(slot) == ru[target].get(slot), (source, target, slot)
assert set("йцукенгшщзхфывапролджэячсмитьбю") <= ru.keys()
for layout, mapping in ((latin, en), (russian, ru)):
    assert layout.get("bottom_row") == "false"
    assert mapping["shift"].get("sw") == "switch_backward"
    assert mapping["ctrl"].get("ne") == "tool:app.command_palette:󱎱"
    assert mapping["ctrl"].get("n") == "loc meta"
    for slot, direction in (("w", "left"), ("e", "right"), ("n", "up"), ("s", "down")):
        assert mapping["space"].get(slot) == "cursor_" + direction
    assert mapping["space"].get("sw") == "tool:session.previous:󰜹"
    assert mapping["space"].get("se") == "tool:session.next:󰜰"
    assert mapping["enter"].get("s") == "^↵:ctrl,enter"
for name in ("shift", "ctrl", "space", "loc alt", "loc compose", "enter", "backspace"):
    for slot in slots:
        assert en[name].get(slot) == ru[name].get(slot), (name, slot)
en_fn = {key.get("a"): key.get("b") for key in latin.find("modmap")}
ru_fn = {key.get("a"): key.get("b") for key in russian.find("modmap")}
assert {pairs[key]: action for key, action in en_fn.items() if pairs[key] not in ("т", "ь", "б", "ю")} == ru_fn
for char, gestures in {"т": {"ne": ";"}, "ь": {"ne": ":"},
                       "б": {"se": ","}, "ю": {"se": "."}}.items():
    assert ru[char].attrib == {"c": char, **gestures}, char
    assert char not in ru_fn
for key, slot, action in (("c", "ne", "^c:ctrl,c"), ("d", "ne", "^d:ctrl,d"),
                          ("z", "ne", "⌥z:alt,z")):
    assert en[key].get(slot) == action
for mapping, a, s, e, o, j, k in ((en, "a", "s", "e", "o", "j", "k"), (ru, "ф", "ы", "у", "щ", "о", "л")):
    assert mapping[a].get("sw") == "tab" and mapping[a].get("s") is None
    assert mapping[s].get("sw") == "tool:session.new:⁺"
    assert mapping[s].get("nw") == "tool:session.previous:‹"
    assert mapping[s].get("ne") == "tool:session.next:›"
    assert mapping[e].get("se") is None and mapping[o].get("nw") is None
    assert mapping[j].get("ne") == chr(34) and mapping[k].get("ne") == "'"
    assert all(not value.endswith((":ctrl,e", ":ctrl,o")) for key in mapping.values() for value in key.attrib.values())
assert en["m"].attrib == {"c": "m", "sw": ",", "se": "."}
assert ru["ж"].attrib == {"c": "ж"} and ru["д"].attrib == {"c": "д"}
assert en["l"].get("ne") == "|" and en["l"].get("sw") == "\\\\"
assert ru["э"].get("ne") == "|" and ru["э"].get("sw") == "\\\\"
assert ru["п"].get("ne") == "=" and ru["п"].get("sw") == "+"
assert en["p"].get("sw") == ":keyevent flags='small' symbol='F7':137"
assert en["p"].get("se") == ":keyevent flags='small' symbol='F8':138"
# Геометрия как в KeyboardData.Row: scale нормирует ширины всех клавиш ряда.
def geometry(row):
    total = sum(float(key.get("width", "1")) + float(key.get("shift", "0")) for key in row)
    factor = float(row.get("scale", total)) / total
    left, result = 0.0, {}
    for key in row:
        left += float(key.get("shift", "0")) * factor
        right = left + float(key.get("width", "1")) * factor
        result[key.get("c")] = (left, right)
        left = right
    return left, result

letter_width, letters = geometry(russian.findall("row")[2])
bottom_width, bottom = geometry(russian.findall("row")[3])
assert abs(bottom_width - letter_width) < 0.001, "Russian bottom row must fill the keyboard"
assert abs(bottom["enter"][0] - letters["backspace"][0]) < 0.03, "Enter must align below Backspace"
assert bottom["enter"][0] >= letters["ю"][1] - 0.03, "Enter must not sit below the period key"
assert abs(bottom["enter"][1] - letter_width) < 0.001
assert float(ru["space"].get("width")) > float(en["space"].get("width"))
print("PASS: both layouts, shared gestures/Fn actions, simplified Russian punctuation, four-way sliders and ё")

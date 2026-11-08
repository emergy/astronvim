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
    if target in ("т", "ь"):
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
                       "б": {"ne": "'", "se": ","}, "ю": {"ne": chr(34), "se": "."}}.items():
    assert ru[char].attrib == {"c": char, **gestures}, char
    assert char not in ru_fn
for key, slot, action in (("c", "ne", "^c:ctrl,c"), ("d", "ne", "^d:ctrl,d"),
                          ("e", "se", "^e:ctrl,e"), ("o", "nw", "^o:ctrl,o"),
                          ("z", "ne", "⌥z:alt,z")):
    assert en[key].get(slot) == action
assert en["p"].get("sw") == ":keyevent flags='small' symbol='F7':137"
assert en["p"].get("se") == ":keyevent flags='small' symbol='F8':138"
print("PASS: both layouts, shared gestures/Fn actions, simplified Russian punctuation, four-way sliders and ё")

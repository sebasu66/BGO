#!/usr/bin/env python3
"""Generate the read-only BGO Studio from component manifests.

Source of truth stays in text: component.jsonh, MODULE.md (concept), the .gd code, tests and git.
Output (generated, disposable): .engine/studio/index.html
Usage: python scripts/build_studio.py [--open]
"""
import html
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / ".engine" / "studio" / "index.html"
ICONS = {"board": "▦", "piece": "♟", "hand": "✋", "grid": "▤", "slot": "◎", "container": "📦", "ui": "🖥"}
COLORS = {"board": "#c08a3e", "piece": "#d9534f", "hand": "#5b9bd5", "grid": "#8e7cc3", "slot": "#6aa84f", "container": "#c27ba0", "ui": "#45a29e"}
e = html.escape


def git_last(folder):
    r = subprocess.run(["git", "log", "-1", "--format=%cs  %s", "--", str(folder)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return r.stdout.strip() or "never committed"


def md_lite(text):
    out, in_list = [], False
    for line in text.splitlines():
        if line.startswith("- "):
            out.append(("" if in_list else "<ul>") + f"<li>{e(line[2:])}</li>")
            in_list = True
            continue
        if in_list:
            out.append("</ul>")
            in_list = False
        m = re.match(r"(#{1,3}) (.*)", line)
        out.append(f"<h4>{e(m.group(2))}</h4>" if m else (f"<p>{e(line)}</p>" if line.strip() else ""))
    return "".join(out) + ("</ul>" if in_list else "")


def load():
    caps = json.loads((ROOT / "src/capabilities/capabilities.jsonh").read_text(encoding="utf-8")).get("capabilities", {})
    tests = {p.name: p.read_text(encoding="utf-8", errors="replace") for p in (ROOT / "tests").glob("*.gd")}
    items = []
    for mf in sorted((ROOT / "src/components").rglob("component.jsonh")):
        folder = mf.parent
        item = {"folder": folder.relative_to(ROOT).as_posix(), "checks": []}
        try:
            m = json.loads(mf.read_text(encoding="utf-8"))
        except ValueError as err:
            item.update(id=folder.name, kind="?", desc="", m={}, bad=str(err))
            items.append(item)
            continue
        gds = sorted(folder.glob("*.gd"))
        code = "\n\n".join(f"# ---- {g.name} ----\n{g.read_text(encoding='utf-8', errors='replace')}" for g in gds)
        tokens = {m["id"], folder.name} | {g.stem for g in gds}
        hits = sorted(n for n, t in tests.items() if any(k in t for k in tokens))
        concept = folder / "MODULE.md"
        ctext = concept.read_text(encoding="utf-8") if concept.exists() else None
        status = re.search(r"^status:\s*(\w+)", ctext or "", re.M)
        unknown = [c for c in m.get("capabilities", []) if c not in caps]
        item.update(id=m["id"], kind=m.get("kind", "?"), desc=m.get("description", ""), m=m, bad=None, code=code, lines=code.count("\n"), tests=hits,
                    console="func console_api" in code, concept=ctext, concept_status=(status.group(1) if status else ("draft" if ctext else "none")),
                    git=git_last(folder), unknown=unknown)
        item["checks"] = [("manifest valid", True, "schema ok"), ("known capabilities", not unknown, ", ".join(unknown) or "all in catalog"),
                          ("console API", item["console"], "console_api() present" if item["console"] else "missing"),
                          ("tests reference it", bool(hits), f"{len(hits)} test file(s)" if hits else "no test references it")]
        item["level"] = "red" if unknown else ("green" if all(c[1] for c in item["checks"]) else "yellow")
        items.append(item)
    for i in items:
        if i["bad"]:
            i["level"], i["checks"] = "red", [("manifest valid", False, i["bad"])]
    return items


def draft_concept(i):
    m = i["m"]
    cfg, verbs = list(m.get("config", {})), list(m.get("verbs", {}))
    return (f"<p><b>{e(i['desc'])}</b></p><p>Behaves as: {e(', '.join(m.get('capabilities', [])) or 'nothing declared')}.</p>"
            f"<p>Configurable: {e(', '.join(cfg) or 'nothing')}.</p><p>Commands it accepts: {e(', '.join(verbs) or 'none')}.</p>")


def card(i):
    m, k = i["m"], i["kind"]
    cfg = m.get("config", {})
    caps = "".join(f'<span class="chip" data-cap="{e(c)}">{e(c)}</span>' for c in m.get("capabilities", []))
    rows = "".join(f'<tr><td>{e(n)}</td><td>{e(str(s.get("type", "")))}</td><td>{e(str(s.get("default", "")))}</td></tr>' for n, s in cfg.items())
    verbs = "".join(f"<li><code>{e(v)}</code></li>" for v in m.get("verbs", {}))
    checks = "".join(f'<li class="{"ok" if ok else "no"}">{"✔" if ok else "✖"} {e(n)} <small>{e(d)}</small></li>' for n, ok, d in i["checks"])
    if i["concept"]:
        concept = f'<span class="tag {i["concept_status"]}">concept: {i["concept_status"]}</span>' + md_lite(i["concept"])
    else:
        concept = '<span class="tag none">auto-draft from manifest · not validated</span>' + draft_concept(i)
    return f'''<article class="card {i["level"]}" data-caps="{e(" ".join(m.get("capabilities", [])))}" style="--k:{COLORS.get(k, "#888")}">
<div class="z0"><div class="sym">{ICONS.get(k, "◆")}</div><h3>{e(i["id"])}</h3><div class="light"></div></div>
<div class="z1"><div class="chips">{caps}</div><ul class="checks">{checks}</ul>
<details><summary>{len(cfg)} config · {len(m.get("verbs", {}))} verbs</summary><table>{rows}</table><ul>{verbs}</ul></details></div>
<div class="z2">{concept}</div>
<div class="z3"><small>{e(i["folder"])} · {i.get("lines", 0)} lines · last change {e(i.get("git", ""))}</small><details><summary>source</summary><pre>{e(i.get("code", ""))}</pre></details></div></article>'''


CSS = """:root{--bg:#f4f1ea;--fg:#222;--card:#fff;--mut:#777}@media(prefers-color-scheme:dark){:root{--bg:#16171a;--fg:#e8e6e1;--card:#202226;--mut:#8b8f96}}
body{margin:0;font:14px system-ui,sans-serif;background:var(--bg);color:var(--fg)}header{position:sticky;top:0;background:var(--bg);padding:12px 20px;border-bottom:1px solid #8884;z-index:2;display:flex;gap:12px;align-items:center;flex-wrap:wrap}
header h1{font-size:16px;margin:0 12px 0 0}button{padding:6px 12px;border:1px solid #8886;background:var(--card);color:var(--fg);border-radius:6px;cursor:pointer}button.on{background:var(--fg);color:var(--bg)}
section{padding:8px 20px}section h2{font-size:12px;text-transform:uppercase;letter-spacing:.08em;color:var(--mut)}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:12px}
body.zoom-1 .grid,body.zoom-2 .grid,body.zoom-3 .grid{grid-template-columns:repeat(auto-fill,minmax(340px,1fr))}
.card{background:var(--card);border-radius:10px;border-top:4px solid var(--k);padding:12px;position:relative;overflow:auto}.card.dim{opacity:.18}
.sym{font-size:44px;text-align:center}.z0 h3{font-size:12px;text-align:center;margin:4px 0;word-break:break-all}.light{position:absolute;top:8px;right:8px;width:12px;height:12px;border-radius:50%;background:#aaa}
.green .light{background:#3fb950}.yellow .light{background:#d29922}.red .light{background:#f85149}.z1,.z2,.z3{display:none;margin-top:8px}body.zoom-1 .z1,body.zoom-2 .z1,body.zoom-3 .z1,body.zoom-2 .z2,body.zoom-3 .z2,body.zoom-3 .z3{display:block}
.chip{display:inline-block;background:#8883;border-radius:10px;padding:1px 8px;margin:2px;font-size:11px;cursor:pointer}.checks{list-style:none;padding:0;margin:6px 0}.ok{color:#3fb950}.no{color:#f85149}.checks small,small{color:var(--mut)}
.tag{font-size:11px;padding:1px 8px;border-radius:10px;background:#8883}.tag.validated{background:#3fb95044}.tag.none{background:#d2992244}pre{max-height:320px;overflow:auto;font-size:11px;background:#0002;padding:8px}table{font-size:12px;width:100%}"""
JS = """const b=document.body;document.querySelectorAll('[data-z]').forEach(x=>x.onclick=()=>{b.className='zoom-'+x.dataset.z;document.querySelectorAll('[data-z]').forEach(y=>y.classList.toggle('on',y===x))});
let cap=null;document.addEventListener('click',ev=>{const c=ev.target.closest('.chip');if(!c)return;cap=cap===c.dataset.cap?null:c.dataset.cap;document.querySelectorAll('.card').forEach(k=>k.classList.toggle('dim',!!cap&&!k.dataset.caps.split(' ').includes(cap)));document.getElementById('f').textContent=cap?'filter: '+cap+' (click again to clear)':''})"""


def main():
    items = load()
    kinds = sorted({i["kind"] for i in items})
    body = "".join(f'<section><h2>{e(k)}</h2><div class="grid">{"".join(card(i) for i in items if i["kind"] == k)}</div></section>' for k in kinds)
    n = {lv: sum(i["level"] == lv for i in items) for lv in ("green", "yellow", "red")}
    page = (f'<!doctype html><meta charset="utf-8"><title>BGO Studio</title><style>{CSS}</style><body class="zoom-0"><header><h1>BGO Studio</h1>'
            f'<button data-z="0" class="on">Symbol</button><button data-z="1">Ports &amp; checks</button><button data-z="2">Concept</button><button data-z="3">Code</button>'
            f'<span>{len(items)} components · 🟢 {n["green"]} 🟡 {n["yellow"]} 🔴 {n["red"]}</span><small id="f"></small></header>{body}<script>{JS}</script>')
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(page, encoding="utf-8")
    print(f"Studio: {len(items)} components -> {OUT.relative_to(ROOT)}  (green {n['green']}, yellow {n['yellow']}, red {n['red']})")
    if "--open" in sys.argv:
        import os
        os.startfile(OUT)


if __name__ == "__main__":
    main()

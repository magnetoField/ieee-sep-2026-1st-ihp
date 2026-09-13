"""Validate generated wiki links and the real layout asset; no ASIC tests."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit, unquote
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "wiki/site"


class Page(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.ids = set()
        self.refs = []
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if attrs.get("id"):
            self.ids.add(attrs["id"])
        for name in ("href", "src"):
            if attrs.get(name):
                self.refs.append(attrs[name])


pages = {p: Page(p.read_text()) for p in SITE.glob("*.html")}
assert len(pages) >= 12, "Build the wiki first"
errors = []
count = 0
for path, page in pages.items():
    for ref in page.refs:
        url = urlsplit(ref)
        if url.scheme or url.netloc:
            continue
        # Generated HTTP 404 uses site-root URLs, not filesystem-root paths.
        base = SITE if url.path.startswith("/") else path.parent
        target = (base / unquote(url.path).lstrip("/")).resolve() if url.path else path
        if target.is_dir():
            target /= "index.html"
        if not target.exists():
            errors.append(f"{path.name}: missing {ref}")
        elif url.fragment and target in pages:
            if unquote(url.fragment) not in pages[target].ids:
                errors.append(f"{path.name}: missing anchor {ref}")
        count += 1
assert not errors, "\n".join(errors)
index = json.loads((SITE / "search/search_index.json").read_text())
assert any("CHALLENGE_READY" in item.get("text", "") for item in index["docs"])
source = (ROOT / "wiki/assets/chip-d6-layout.png").read_bytes()
assert source == (SITE / "assets/chip-d6-layout.png").read_bytes()
assert all("rumcajs" not in p.read_text().lower() for p in pages)
print(f"PASS: {len(pages)} generated HTML pages, {count} local references/anchors")
print(f"PASS: search index contains {len(index['docs'])} entries including CHALLENGE_READY")
print("PASS: layout preserved, SHA256 " + hashlib.sha256(source).hexdigest())
print("PASS: no legacy product name in generated pages")

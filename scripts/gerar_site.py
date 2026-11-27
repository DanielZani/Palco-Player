"""Gera dist/index.html e os guias estáticos da mesma revisão do produto."""
from html import escape
from pathlib import Path
import re
import shutil
import tempfile
import unicodedata
from urllib.parse import unquote, urlsplit, urlunsplit

from lxml import html
from markdown_it import MarkdownIt

ROOT = Path(__file__).resolve().parents[1]
GUIDES = ("arquitetura", "manual")
PAGES = {name + ".md": name + ".html" for name in GUIDES}


def fragment_for(title):
    normalized = unicodedata.normalize("NFKD", title).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", normalized.lower()).strip("-") or "secao"


def render(name, style):
    source = (ROOT / "docs" / (name + ".md")).read_text(encoding="utf-8")
    markup = MarkdownIt("commonmark", {"html": True}).enable("table").render(source)
    article = html.fragment_fromstring(markup, create_parent="article")
    titles = article.xpath("./h1")
    if len(titles) != 1:
        raise ValueError(f"{name}.md precisa de um único título principal")
    heading = titles[0]
    title = heading.text_content()
    intro = heading.getnext()
    article.remove(heading)
    lead = ""
    if intro is not None and intro.tag == "p" and not intro.xpath(".//a"):
        article.remove(intro)
        lead = html.tostring(intro, encoding="unicode")

    for a in article.xpath(".//a[@href]"):
        u = urlsplit(a.get("href"))
        path = u.path.removeprefix("./")
        if not u.scheme and not u.netloc and path in PAGES:
            a.set("href", urlunsplit(("", "", PAGES[path], u.query, u.fragment)))

    used = set(article.xpath(".//@id | .//a/@name"))
    menu = []
    for h in article.xpath("./h2"):
        prev = h.getprevious()
        anchors = prev.xpath("./a[@name]") if prev is not None and prev.tag == "p" else []
        if len(anchors) == 1 and not prev.text_content().strip() and len(prev) == 1:
            anchor = anchors[0].get("name")
            article.remove(prev)
        else:
            base = fragment_for(h.text_content())
            anchor = base
            i = 1
            while anchor in used:
                i += 1
                anchor = f"{base}-{i}"
        used.add(anchor)
        h.set("id", anchor)
        menu.append(f'<a href="#{escape(anchor, quote=True)}">{escape(h.text_content())}</a>')

    for table in article.xpath(".//table"):
        headers = table.xpath("./thead/tr/th")
        for th in headers:
            th.set("scope", "col")
        for row in table.xpath("./tbody/tr"):
            for td, th in zip(row.xpath("./td"), headers):
                td.set("data-label", th.text_content())

    toc = "".join(menu)
    body = html.tostring(article, encoding="unicode")
    return f"""<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{escape(title)}</title><style>{style}</style></head><body>
<a class="skip" href="#conteudo">Ir para o conteúdo</a>
<header><div class="wrap"><div class="bar"><a class="brand" href="../index.html">Palco <b>Player</b></a>
<a href="../index.html">Abrir player</a></div><div class="hero"><h1>{escape(title)}</h1>{lead}</div></div></header>
<main class="columns wrap" id="conteudo"><nav class="idx" aria-label="Sumário"><div class="wide-nav"><strong>Sumário</strong>{toc}</div>
<details class="mobile-nav"><summary>Sumário da página</summary>{toc}</details></nav>{body}</main></body></html>
"""


def validate(site):
    for page in (site / "docs").glob("*.html"):
        doc = html.parse(page)
        anchors = doc.xpath("//@id | //a/@name")
        if len(set(anchors)) != len(anchors):
            raise ValueError(f"Âncora duplicada em {page.name}")
        for href in doc.xpath("//a/@href"):
            url = urlsplit(href)
            if url.scheme or url.netloc:
                continue
            target = (page.parent / unquote(url.path)).resolve() if url.path else page
            if not target.is_relative_to(site) or not target.is_file():
                raise ValueError(f"{page.name}: destino inexistente: {href}")
            if url.fragment:
                available = html.parse(target).xpath("//@id | //a/@name")
                if unquote(url.fragment) not in available:
                    raise ValueError(f"{page.name}: seção inexistente: {href}")


def main():
    style = (ROOT / "scripts/guias.css").read_text(encoding="utf-8")
    with tempfile.TemporaryDirectory() as tmp:
        stage = Path(tmp).resolve()
        (stage / "docs").mkdir()
        shutil.copyfile(ROOT / "index.html", stage / "index.html")
        for name in GUIDES:
            (stage / "docs" / (name + ".html")).write_text(render(name, style), encoding="utf-8")
        validate(stage)
        shutil.copytree(stage, ROOT / "dist", dirs_exist_ok=True)
    print("Site gerado e validado em dist/.")


if __name__ == "__main__":
    main()

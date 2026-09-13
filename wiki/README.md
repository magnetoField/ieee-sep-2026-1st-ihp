# D00RSH Wiki — MkDocs

Źródła dokumentacji: `manual/*.md`. Framework: MkDocs 1.6.1,
motyw Read the Docs z lokalnym arkuszem stylów klasycznej wiki.
Inspiracja organizacją: https://stm32world.com/wiki/Main_Page.
Własne teksty i grafiki projektu; bez kopiowania logo i treści STM32World.

Z katalogu głównego repozytorium:

```sh
make wiki-build
make wiki-serve
```

Podgląd: http://127.0.0.1:8000. Zatrzymanie serwera: Ctrl+C.
Gotowe strony HTML znajdują się w `wiki/site/`, wejście: `wiki/index.html`.
Do publikacji wystarczy cały katalog `wiki/site/`.
Nawigacja działa także z pliku; wyszukiwanie wymaga HTTP.

Środowisko użyte lokalnie: `.tools/wiki-env`. Na nowym stanowisku:

```sh
python3 -m venv .tools/wiki-env
.tools/wiki-env/bin/python -m pip install -r wiki/requirements-lock.txt
make wiki-build
```

Wygląd: `manual/assets/wiki.css`; nawigacja: `mkdocs.yml`.
Obraz layoutu pochodzi z istniejącego renderu końcowego projektu.
Poprzednia strona zachowana w `archive/index-v1.html`.

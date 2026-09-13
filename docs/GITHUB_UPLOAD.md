# D00RSH — publiczne repozytorium i Tiny Tapeout

Projekt przygotowany dla **Tiny Tapeout IHP26b, IHP SG13G2, 1×1, 1 MHz**.
Nie zmieniaj technologii na SKY ani nazwy fizycznego topa przy publikacji tej wersji.

## Przed publikacją

Metadane są uzupełnione: **D00RSH**, **Koło Naukowe BAZA — ZT, PN, MK, JT, KK**.
Pole Discord jest opcjonalne. Sprawdź pisownię przed pierwszym push.
Tożsamość autora commitu Git ustaw osobno na swoim komputerze.

Uruchom z głównego katalogu repozytorium:

```sh
make upload-check PYTHON=.tools/wiki-env/bin/python
make release-check
make wiki-build
```

`upload-check` sprawdza pliki, metadane, listę źródeł, workflow i podstawowe wzorce
sekretów w plikach planowanych do publikacji. Nie jest dowodem braku wszystkich
sekretów. Klucz i PIN demonstracyjne są celowo jawne.

Lokalne środowisko PDK, narzędzia, przebiegi i katalogi runs są ignorowane przez Git.
Raporty i zweryfikowany GDS pozostają dowodami lokalnymi. GitHub zbuduje własne
artefakty do zgłoszenia z opublikowanego commitu.

## Utworzenie publicznego repozytorium

Na GitHub utwórz puste **publiczne** repozytorium, np. `D00RSH`.
Nie inicjalizuj go dodatkowym README/licencją: te pliki już są w projekcie.
Repozytorium nie ma jeszcze pierwszego commitu ani zdalnego `origin`.
Istniejący remote `template` nie jest miejscem publikacji projektu.

W GitHub Desktop dodaj ten katalog jako istniejące repozytorium, przejrzyj
zmiany i utwórz pierwszy commit. Alternatywnie użyj poniższych poleceń po
ustawieniu własnej tożsamości Git. Zastąp OWNER nazwą swojego konta/organizacji:

```sh
git add .
git diff --cached --stat
git commit -m "Prepare D00RSH for Tiny Tapeout IHP26b"
git remote add origin https://github.com/OWNER/D00RSH.git
git push -u origin main
```

To polecenia do wykonania po przeglądzie publikowanych plików; przygotowanie
paczki nie wykonuje commitu ani push. Jeśli origin już istnieje, sprawdź
`git remote -v` zamiast dodawać go ponownie.

Zalecany jest Git/GitHub Desktop: zachowuje ukryty katalog `.github` i uprawnienia
skryptów. Przy ręcznym przesyłaniu plików przez stronę GitHub łatwo pominąć
workflow. ZIP jest paczką transportową — Tiny Tapeout nie dostaje samego ZIP-a
zamiast działającego repozytorium.

## GitHub Actions i Pages

Włącz Actions w repozytorium. W Settings → Pages wybierz źródło **GitHub Actions**.
Stroną Pages zarządza oficjalny viewer Tiny Tapeout; wiki jest osobnym artefaktem
`chip-d6-wiki` w zakładce Actions, więc nie nadpisuje viewera.

Poczekaj na wymagane wyniki dla tego samego commitu:

| Workflow / job | Co sprawdza |
|---|---|
| rtl-regression / test | Modele, RTL, integracja, exhaustive, formal, mutacje i synteza |
| gds / gds | Oficjalne hardening i artefakt `tt_submission` dla IHP |
| gds / precheck | Oficjalne kontrole plików produkcyjnych |
| gds / gl_test | Rzeczywista netlista z artefaktu, Icarus 13, wyniki JUnit |
| gds / viewer | Podgląd fizyczny na Pages |
| docs / docs | Datasheet z `info.yaml` i `docs/info.md` |
| wiki / build | MkDocs i lokalne odnośniki |

Pierwszy zdalny przebieg jest wymagany: lokalny PASS nie oznacza PASS na GitHub.
Regresja RTL używa przypiętego OSS CAD Suite z 12 września 2026 r.; sama akcja
konfigurująca jest przypięta pełnym identyfikatorem commitu.
Action IHP26b używa swojego pakietu PDK; lokalny historyczny flow był uruchomiony
na raw PDK wskazanym w raportach. Porównuj wyniki, nie zakładaj identycznego GDS.

## Import do Tiny Tapeout

Po przejściu CI otwórz aplikację Tiny Tapeout, wybierz właściwy shuttle IHP
i wskaż publiczne repozytorium oraz zaakceptowaną wersję projektu. Sprawdź
metadane, rozmiar 1×1 i status wszystkich kontroli. Dostępność IHP26b należy
potwierdzić w aplikacji; ta paczka nie rezerwuje miejsca w shuttle.

Zamówienie, płatność i ostateczne zgłoszenie są osobnymi czynnościami.

## Źródła

- [Oficjalny template IHP](https://github.com/TinyTapeout/ttihp-verilog-template)
- [FAQ Tiny Tapeout](https://tinytapeout.com/faq/)
- [Aplikacja zgłoszeń](https://app.tinytapeout.com/)
- [Lokalne dowody i ograniczenia](../reports/FINAL.md)

`RTL_DEMO`, `VERIFICATION`, `FIT_1_TILE`, `PHYSICAL_CHECKS`: lokalne PASS według
raportu. `PRODUCTION_PERSISTENCE=NOT_IMPLEMENTED`. Brak trwałej blokady,
chronionego provisioningu i pomiarów krzemu.

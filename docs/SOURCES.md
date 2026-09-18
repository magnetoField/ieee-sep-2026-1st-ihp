# Źródła pierwotne i zakres wykorzystania

Sprawdzone przy przygotowaniu planu: 2026-09-12. Źródła zewnętrzne opisują platformę i algorytm; decyzje takie jak PIN=1234, auto-submit, progi debounce, framing SHIFT64 i bitowa mikroarchitektura są decyzjami niniejszego projektu, nie wymaganiami narzuconymi przez Tiny Tapeout ani autorów SIMON.

## S1 — OpenAI, Developer commands

`https://learn.chatgpt.com/docs/developer-commands?surface=cli`

Oficjalna dokumentacja, sekcja „Set or view a task goal with /goal”: składnia `/goal <objective>`, cel przypięty do rozmowy i limit 4000 znaków; dłuższe instrukcje należy umieszczać w plikach. Dokument był dostępny także przez przekierowanie z `https://developers.openai.com/codex/cli/slash-commands`.

## S2 — Tiny Tapeout, GPIO pins

`https://tinytapeout.com/specs/gpio/`

Interfejs 8 wejść, 8 wyjść, 8 pinów dwukierunkowych plus zegar/reset; parametry i ograniczenia konkretnych padów/demoboardu. Nie przenosić podanych parametrów SKY bez sprawdzenia na IHP/GF.

## S3 — Tiny Tapeout, oficjalne template

`https://tinytapeout.com/hdl/templates/`

`https://github.com/TinyTapeout/ttihp-verilog-template/blob/main/src/project.v`

Wybrany target to TTIHP26b / `ihp-sg13g2`; dokładne commity template, action,
PDK i support tools są przypięte w `reports/TARGET.md`. Interfejs wrappera
obejmuje `uio_in`, `uio_out`, `uio_oe`.

## S4 — Tiny Tapeout, Memory

`https://tinytapeout.com/specs/memory/`

Koszt pamięci DFF, orientacyjna liczba około 320 DFF w tile i alternatywy pamięci. To nie gwarancja pojemności każdego aktualnego tile'a ani informacja, że rejestr jest nieulotny. Wniosek dotyczący braku trwałości zwykłego licznika wynika z fizycznej natury DFF i przyjętej architektury MVP.

## S5 — Autorzy SIMON/SPECK, Implementation Guide 1.1

`https://nsacyber.github.io/simon-speck/implementations/`

`https://nsacyber.github.io/simon-speck/implementations/ImplementationGuide1.1.pdf`

SIMON64/128, pełne 44 rundy, porządek słów, kod referencyjny harmonogramu i KAT. Sekcja 10, drukowana strona 24, zawiera wykorzystany wektor `656b696c20646e75` → `44c8fc20b9dfa07a`. Strony drukowane 7–8 opisują referencyjne SIMON64. Obraz strony KAT został sprawdzony, nie tylko tekst wyekstrahowany z PDF.

Plan proponuje własną współdzieloną bitową mikroarchitekturę; sam guide nie jest dowodem jej poprawnej implementacji RTL.

## S6 — Tiny Tapeout, FAQ

`https://tinytapeout.com/faq/`

Historyczne przybliżenie tile'a około 160×100 µm i około 1000 bramek dotyczy sekcji TT04–TT10. W planie jest wyłącznie wskazówką historyczną. Dokładna geometria i powierzchnia użytkowa muszą pochodzić z wybranego aktualnego targetu.

## S7 — Tiny Tapeout, Local hardening

`https://tinytapeout.com/guides/local-hardening/`

Oficjalna procedura uruchamiania lokalnego flow. Wersje narzędzi, PDK i komendy należy dopasować do realnego template, nie kopiować bez sprawdzenia między technologiami. Raport dopasowania ma pochodzić z rzeczywistego hardeningu.

## S8 — Microchip AN3407, Theory of Operation

`https://onlinedocs.microchip.com/oxy/GUID-7F7FEA3F-1F4B-4C3B-B4FE-12A7D22A4773-en-US-8/GUID-0FB8ED2D-33E0-4E92-8BBE-325061B16578.html`

Działanie matrycy, zwarcia R–C, skanowanie i problem ghostingu. Plan nie kopiuje metody identyfikacji klawisza z prostego programu AVR; definiuje pełnoskanowe odrzucanie wielokliku i model sieci elektrycznej odpowiedni dla wierszy 0/Z.

## S9 — NIST SP 800-63B-4

`https://pages.nist.gov/800-63-4/sp800-63b.html`

Świeżość wyzwań i odporność na replay w mechanizmach uwierzytelniania. To źródło uzasadniające potrzebę nonce i jednorazowego kontekstu. **Nie** stanowi deklaracji zgodności protokołu Rumcajs, SIMON ani tego demonstratora z wymaganiami NIST/FIPS/AAL.

## S10 — LibreLane, konfiguracja syntezy

`https://librelane.readthedocs.io/en/latest/reference/step_config_vars.html`

Oficjalna dokumentacja definiuje strategie `AREA 0`–`AREA 3` oraz
`SYNTH_ABC_AREA_USE_NF`. Changelog potwierdza obecność trybu `&nf` przed wersją
3.0.5 przypiętą przez TTIHP26b. Wybór konfiguracji jest nadal hipotezą PPA do
sprawdzenia pełnym flow, a nie dowodem dopasowania.

## S11 — IEEE HART, IEEE Open Silicon Initiative

`https://hart.ieee.org/projects/chip-fabrication/`

Oficjalna strona programu opisuje IEEE Open Silicon Initiative jako program
prototypowania i wytwarzania układów dla studentów. Wymienia IEEE EDS, SSCS,
CASS, CEDA i IEEE Nanotechnology Council jako jednostki zapewniające
finansowanie oraz Tiny Tapeout jako partnera zewnętrznego. Na tej podstawie
sformułowano podziękowanie w publicznej dokumentacji D00RSH.

## S12 — Tiny Tapeout, credits

`https://tinytapeout.com/credits/`

Oficjalna strona Tiny Tapeout przypisuje finansowanie prac nad IHP 130 nm
programowi SwissChips. Jest to odrębne podziękowanie dotyczące infrastruktury
Tiny Tapeout, nie twierdzenie o bezpośrednim grancie dla zespołu D00RSH.

## S13 — Tiny Tapeout, updating project documentation

`https://tinytapeout.com/guides/documentation/`

Oficjalny przewodnik potwierdza, że `info.yaml` i `docs/info.md` są źródłami
publicznej strony projektu oraz że autor, tytuł i pinout należą do metadanych
dokumentacji.

## S14 — Tiny Tapeout, IEEE Open Silicon water-level controller

`https://tinytapeout.com/chips/ttsky26b/tt_um_oreoluwa_water_level`

Opublikowany projekt programu IEEE Open Silicon z osobnym „About this project”,
opisem działania, instrukcją testu i tabelą pinów. D00RSH stosuje ten czytelny
podział, ale nie kopiuje tekstu ani RTL projektu.

## S15 — Tiny Tapeout, related lock and serial-challenge projects

`https://tinytapeout.com/chips/ttsky26b/tt_um_wokwi_461622504612675585`

`https://tinytapeout.com/chips/ttsky26b/tt_um_thorsten_shiftregister`

Pierwszy przykład pokazuje prosty zamek i jawny test sygnałów LED/buzzera;
drugi opisuje przesyłany szeregowo challenge, kolejność bitów, reset i
oczekiwany stan wyjścia. Służą wyłącznie jako porównanie sposobu dokumentacji.

## S16 — Sibling IHP project with evidence-led README

`https://github.com/magnetoField/ieee-sep-2026-2nd-ihp`

Publiczny projekt z tej samej serii pokazuje dobry wzorzec rozdzielenia opisu
interfejsu, procedury weryfikacji, metryk fizycznych i uczciwych ograniczeń.
D00RSH utrzymuje analogiczny rozdział między zachowaniem funkcjonalnym,
dowodami oraz ograniczeniami bezpieczeństwa.

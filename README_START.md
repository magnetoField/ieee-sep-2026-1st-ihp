# Rumcajs — pakiet wykonawczy dla Codexa

Ten plik opisuje historyczny pakiet startowy. RTL i testy już istnieją.
Aktualny kontrakt jednego klucza, READY po poprawnym PIN-ie i 64 cykli
kasowania: [docs/SINGLE_KEY.md](docs/SINGLE_KEY.md). Ma pierwszeństwo
nad poniższym planem dwóch kluczy. Docelowy PDK: IHP SG13G2 / IHP26b.

Wersja planu: 1.0, 2026-09-12. Język dokumentacji: polski. Projekt RTL: Verilog-2005.

To **specyfikacja i plan implementacji**, nie gotowy ASIC. Pakiet nie zawiera zaimplementowanego RTL, wyników jego testbenchy ani wyników syntezy / place-and-route. Zawiera dodatkowo sprawdzony eksperyment arytmetyczny w Pythonie; jego zakres opisano w `docs/ARITHMETIC_CHECK.md`.

## Uruchomienie

Rozpakuj pakiet do katalogu roboczego. W nowym katalogu możesz wykonać:

```sh
git init
codex
```

W interaktywnej sesji Codexa wklej **jedną linię z `GOAL.txt`**. `/goal` jest poleceniem w sesji, nie programem powłoki. Dokumentacja Codexa ogranicza treść celu do 4000 znaków; dlatego długa specyfikacja jest w plikach [S1]. Nie trzeba wklejać wszystkich dokumentów do komendy.

W istniejącym repozytorium Tiny Tapeout zachowaj jego pliki, historię i konfigurację. Scal reguły `AGENTS.md` zamiast bezwarunkowo nadpisywać wcześniejszy plik. Etap P0 ma rozpoznać istniejący template i PDK.

## Co przeczytać

`docs/SPEC.md` jest normatywną specyfikacją funkcjonalną i interfejsową. `docs/TEST_PLAN.md` określa weryfikację każdego bloku i całego układu. `docs/IMPLEMENTATION_PLAN.md` określa kolejność pracy, optymalizację powierzchni i kryteria zakończenia. `docs/SECURITY.md` wyznacza granice demonstratora. `docs/SOURCES.md` zawiera źródła pierwotne.

## Decyzje robocze umożliwiające rozpoczęcie bez kolejnych pytań

Domyślnie: SIMON64/128, 44 rundy; PIN 4-cyfrowy `1234`, automatyczne zatwierdzenie czwartej cyfry; `*` kasuje rozpoczęty PIN, pozostałe klawisze specjalne nie zatwierdzają; trzy błędy łącznie w bieżącym okresie zasilania/resetu; poprawny PIN nie zeruje błędów. Ostatnia dozwolona błędna próba dostaje odpowiedź pod złym kluczem, ale nie może otworzyć następnej sesji.

Błędna próba jest zliczana **przed wystawieniem REQ**, nie po zakończeniu komunikacji. Przerwanie komunikacji jej nie anuluje. Klawiatura zgłasza klawisz po zakończeniu poprawnego naciśnięcia i odfiltrowanym puszczeniu; zaobserwowany wieloklik unieważnia cały gest.

Cel fizyczny: **1 tile, układ 1×1**. Bez wskazanego PDK użyj SKY jako roboczego benchmarku, ale nie twierdź, że jest to wybrany shuttle hackathonu. Wykorzystaj właściwy oficjalny template i zapisz jego commit. Dopasowanie do tile'a musi wynikać z rzeczywistego flow, nie z oszacowania liczby bramek.

## Ograniczenia, których nie wolno ukryć

**Blokada na zawsze po wyłączeniu zasilania nie jest zrealizowana w tej wersji.** Zwykły rejestr prób jest ulotny. MVP ma jawny profil `DEMO_VOLATILE_LOCKOUT`; reset globalny kasuje próby. Dezaktywacja `ena`, przerwanie ramki i timeout nie kasują prób. Wersja produkcyjna wymaga chronionego mechanizmu trwałego zapisu i osobnego przeglądu bezpieczeństwa.

**Klucze i PIN w publicznym RTL są danymi demonstracyjnymi, nie bezpiecznym sposobem provisioningu.** Nie używaj tego demonstratora do zabezpieczania rzeczywistego sejfu.

Źródła oznaczone `[S#]` znajdują się w `docs/SOURCES.md`.

# Sprawdzenie arytmetyki proponowanego Szymona

Data przygotowania planu: 2026-09-12. Status: **PASS wyłącznie dla opisanego eksperymentu w Pythonie**.

## Odtworzenie

Z katalogu głównego pakietu:

```sh
python3 tools/verify_arithmetic_plan.py
```

Wymagana jest tylko biblioteka standardowa Pythona 3. Uruchom bez opcji `-O`, ponieważ eksperyment używa asercji. Pełny zapis wyjścia jest w `docs/ARITHMETIC_CHECK.log`.

## Sprawdzony zakres

Model `ref` wykonuje SIMON64/128 na pełnych słowach 32-bitowych, rozwijając wszystkie klucze rundowe. Model `bitserial` aktualizuje po jednym bicie i stosuje współdzielone, rotowane rejestry opisane w SPEC §9.4. To dwie różne organizacje obliczeń, ale oba modele zostały przygotowane w ramach tego samego planu; nie jest to niezależny audyt.

Obydwa modele przechodzą opublikowany wektor z Implementation Guide 1.1 autorów SIMON/SPECK, sekcja 10, drukowana strona 24 [S5 w `SOURCES.md`]:

```text
key        = 1b1a1918131211100b0a090803020100
plaintext  = 656b696c20646e75
ciphertext = 44c8fc20b9dfa07a
```

Następnie generator `random.Random(0x52554d43)` tworzy **1024 pary**: 64-bitowy plaintext i 128-bitowy klucz. Dla każdej pary porównano końcowy ciphertext i **wszystkie 44 stany po rundach**. To 45 056 porównań stanów rundowych w próbie losowej. Dodatkowo model bitowy sprawdza wyzerowanie czterech roboczych słów harmonogramu po ostatniej rundzie. Generator i seed służą powtarzalności testu, nie generowaniu sekretów.

Dla drugiego, jawnego klucza demonstracyjnego `f0e1d2c3b4a5968778695a4b3c2d1e0f` model słowowy obliczył odpowiedź `9350e3713d63ad28` na ten sam challenge. Ta druga odpowiedź jest **wynikiem obliczenia**, a nie osobnym opublikowanym KAT.

## Wynik rzeczywiście uruchomionego skryptu

```text
Published SIMON64/128 KAT: PASS
Proposed bit-serial arithmetic vs word reference: 1024 random pairs, all 44 round states: PASS
These are Python arithmetic checks only; no RTL, synthesis, layout or hardware has been tested.
Core round cycles: 1408
Demo bad-key response to KAT challenge: 9350e3713d63ad28
```

Liczba 1408 wynika z przyjętych 44 rund po 32 kroki. Przy 1 MHz daje to 1,408 ms samych kroków szyfru. **Nie jest to zmierzona latencja RTL** i nie obejmuje transmisji, handshakingu ani sterowania.

## Czego nie sprawdzono tym eksperymentem

Nie zaimplementowano ani nie uruchomiono RTL, testbenchy modułów, pełnego protokołu, dowodów formalnych, syntezy, place-and-route, STA, DRC/LVS lub sprzętu. Nie potwierdzono dopasowania do 1 tile. Test losowy nie dowodzi poprawności dla wszystkich kluczy i danych ani odporności kryptograficznej. Nie sprawdza błędów nonblocking assignment, resetów, liczników, synchronizatorów, ready–valid ani pinów.

Przyszły RTL musi przejść osobną weryfikację z `TEST_PLAN.md`. Wyniku tego eksperymentu nie wolno przepisać jako `VERIFICATION=PASS` dla ASIC-a.

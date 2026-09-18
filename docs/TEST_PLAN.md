# Rumcajs — plan weryfikacji

**Amendment 2026-09-12:** use [SINGLE_KEY.md](SINGLE_KEY.md) for the current
single-key/authorized-only READY/64-cycle wipe contract. Tests expecting BAD
responses or two-key selection below are superseded by BAD rejection tests.
Current evidence is in [the single-key report](../reports/SINGLE_KEY.md);
older matrix/coverage results are not automatically evidence for this revision.

## 1. Znaczenie wyniku

Celem jest przetestowanie **każdego bloku osobno oraz całości**, w tym zachowań błędnych, resetów, backpressure i wartości granicznych. Nie wolno utożsamiać 100% pokrycia linii ani dużej liczby testów z dowodem wszystkich możliwych zachowań układu fizycznego.

Dla każdego wymagania utrzymuj macierz: ID wymagania, moduł, test/harness, konfiguracja, seed, rezultat, ścieżka do raportu. Statusy: PASS, FAIL, NOT_RUN, BLOCKED, N/A z uzasadnieniem. Brak narzędzia formalnego nie pozwala oznaczyć właściwości formalnych jako udowodnionych. Wynik BMC musi zawierać głębokość, a wynik indukcji informację o założeniach.

Minimalne poziomy: model referencyjny, testy jednostkowe RTL, integracja, formalne własności sterowania, synteza, gate-level smoke, właściwe kontrole fizyczne. Wszystkie konfiguracje fizyczne identyfikuj commitem i parametrami.

## 2. Niezależne modele i infrastruktura

### Model SIMON

`model/simon64_128.py`: zwykła implementacja pełnosłowowa, osobne rozwinięcie 44 kluczy, opcjonalny ślad po rundzie. Opublikowany KAT z `vectors/simon64_128_kat.json` jest niezależnym wzorcem. Model nie może odczytywać kluczy rundowych ani ciphertextu z DUT w celu wyliczenia oczekiwań. Dołączony `tools/verify_arithmetic_plan.py` to dodatkowy eksperyment, nie zastępstwo modelu w testach RTL.

### Model elektryczny klawiatury

Modeluj osiem węzłów: cztery wiersze R0..R3 i cztery kolumny C0..C3. Każdy wciśnięty klawisz łączy odpowiednią parę R–C. Kolumny mają pull-upy, niewybrane wiersze są Z, a wybrany wiersz jest 0. Każda kolumna w spójnej składowej zawierającej wysterowany niski wiersz odczytuje 0; pozostałe kolumny odczytują 1.

To uwzględnia przewodzenie przez niewybrany wiersz i fantomowy czwarty narożnik trzech zwarć. Samo `col = pressed_keys_in_selected_row` jest modelem niewystarczającym do testu ghostingu. Testbench dodatkowo sprawdza, że DUT nigdy nie wymusza wiersza na 1 ani dwóch wierszy naraz.

Własny model grafowy sprawdź prostymi ręcznymi przykładami: brak klawiszy, jedno zwarcie, dwa w jednym wierszu, dwa w jednej kolumnie, trzy narożniki prostokąta, pełna macierz. Model nie musi symulować analogowego RC; ograniczenie to ma być jawne.

### Model protokołu i sejfu

BFM steruje rzeczywistymi portami SDI/SCLK/CS, odczytuje REQ/RSP_READY/SDO i respektuje specyfikowane czasy. Osobny scoreboard utrzymuje liczbę dopuszczonych PIN-ów, błędów, tokenów sesji, użytych challenge i przewidywany wynik. Test end-to-end nie może zastępować fizycznego wciśnięcia klawisza zapisem do wewnętrznego rejestru PIN-u.

Do jednostkowego testowania kontrolera wolno podłączyć modele kb/szyfru/linku z wymuszalnym backpressure i błędami. Do testu rzeczywistej całości podłącz rzeczywiste moduły. Monitoruj nie tylko końcowy wynik, ale liczbę handshake i momenty zmian sygnałów.

W CI zapisuj seed, komendę, wersję narzędzi i manifest testów. VCD/FST zapisuj przede wszystkim dla błędów i wybranych scenariuszy demonstracyjnych; nie generuj setek gigabajtów przebiegów z regresji losowej.

## 3. Rejestr testbenchy

| Moduł | Wymagany test jednostkowy / harness | Główna obserwacja |
|---|---|---|
| `sync2` lub odpowiednik | `tb_sync2` | Opóźnienie i reset dla WIDTH=1 oraz WIDTH=4 |
| `reset_release` | `tb_reset_release` | Asynchroniczne wymuszenie, synchroniczne zwalnianie, brak zegara |
| `timebase` | `tb_timebase` | Dokładna liczba cykli i szerokość ticków |
| `kb` | `tb_kb` + elektryczny model matrycy | Gesty, debounce, ghosting, ready–valid |
| `regs` | `tb_regs` | Cyfry, porównanie, limit prób, kontekst, reset domen |
| `szymon` | `tb_szymon` + niezależny model | KAT, 44 rundy, bit order, handshake, abort |
| `szymon_fixed` | `tb_szymon_fixed` + integracja losowa | Dwie pary parametrów kluczy, GOOD/BAD, latencja, abort i zgodność z modelem |
| `serial_link` | `tb_serial_link` | RX/TX, długość ramek, fazy zegarów, pending bit |
| `auth_ctrl` | `tb_auth_ctrl` | Jednorazowy token, wybór klucza, timeout, ostatnia próba |
| `buzzer` | `tb_buzzer` | Długość impulsu i tonu, trigger podczas busy |
| `rumcajs` | `tb_rumcajs` | Cały przepływ od fizycznego klawisza do odpowiedzi |
| `tt_um_rumcajs` | `tb_tt_um_rumcajs` | Mapowanie pinów, OE, maskowanie, nieużywane wejścia |

Każdy dodatkowy adapter, podmoduł szyfru, licznik lub dekoder wydzielony do osobnego modułu dopisz do tej tabeli i utwórz dla niego test. Sama instancja w teście nadrzędnym nie spełnia wymogu „osobno”. Można współdzielić kod harnessu, ale raport musi identyfikować testowany moduł.

## 4. Testy jednostkowe

### 4.1 Synchronizacja, reset i timebase

| ID | Scenariusz | Warunek PASS |
|---|---|---|
| RST-01 | Reset przy pracującym clk, zwolnienie w różnych fazach | Zwolnienie tylko po określonej liczbie zboczy; brak przypadkowego valid |
| RST-02 | Reset przy zatrzymanym clk | Bezpieczne wyjścia wymuszone bez oczekiwania na zegar |
| RST-03 | `ena=0`, następnie `ena=1`, zegar przez cały ten czas zatrzymany | Po wznowieniu zegara poprzednia sesja jest skasowana, próby zachowane |
| RST-04 | Zimny reset po błędach i po LOCKED | Demo resetuje licznik; test jawnie dokumentuje ograniczenie trwałości |
| CDC-01 | WIDTH=1/4, zbocza pomiędzy zboczami clk | Wyjścia odpowiadają opóźnionym wejściom, bez użycia pierwszego stopnia w logice |
| TME-01 | Domyślne dzielenie i kilka poprawnych parametrów | scan_tick co DIV, ms_tick co 4 scan_tick, szerokość 1 cykl |
| TME-02 | Reset w połowie odliczania | Następny okres i faza są zgodne z dokumentacją |
| TME-03 | Parametry zerowe, niedzielne, zbyt mały DIV | Jawny błąd konfiguracji, nie cichy błędny zegar |

Symulacja cyfrowa CDC nie dowodzi braku metastabilności. Raport zawiera osobno przegląd topologii synchronizatorów oraz założeń czasowych.

### 4.2 Klawiatura

| ID | Scenariusz | Warunek PASS |
|---|---|---|
| KB-01 | Brak klawiszy przez długi czas | Zero zdarzeń |
| KB-02 | Każdy z 16 klawiszy osobno | Po puszczeniu dokładnie jedno zdarzenie z poprawnym `key_id` |
| KB-03 | Press o długości N−1, N, N+1 pełnych zgodnych skanów | Kwalifikacja dokładnie według PRESS_FRAMES |
| KB-04 | Release o długości M−1, M, M+1 skanów | Zdarzenie/uzbrojenie dokładnie według RELEASE_FRAMES |
| KB-05 | Serie drgań podczas naciśnięcia i puszczenia | Brak wielu zdarzeń; za krótki gest daje zero |
| KB-06 | Bardzo długie trzymanie | Brak autorepeat, brak zdarzenia przed puszczeniem |
| KB-07 | Wszystkie 120 nieuporządkowanych par | Zero zaakceptowanych klawiszy z całego gestu |
| KB-08 | Trzy narożniki każdego prostokąta i pełne prostokąty | Fantomowy klawisz nie jest akceptowany |
| KB-09 | Pojedynczy → dwa → pojedynczy → puszczenie | Cały gest odrzucony, nie ma „uratowanego” klawisza |
| KB-10 | ONE(A) → ONE(B) bez stabilnego puszczenia | Odrzucenie, także gdy nie wypadła próbka MULTI |
| KB-11 | Drugi klawisz tuż przed końcem debounce i podczas release | Odrzucenie, o ile został zaobserwowany zgodnie z umową próbkowania |
| KB-12 | Trzymanie klawisza przez reset/flush/disable | Nie pojawia się jako nowy klawisz po wznowieniu |
| KB-13 | `key_ready=0` przez losowo długi czas | `key_valid` i `key_id` stabilne; brak nadpisania |
| KB-14 | Nowe gesty podczas oczekiwania na odbiór | Nie nadpisują pending; po odbiorze wymagane świeże stabilne puszczenie |
| KB-15 | `ready=1` bez valid; ready pulsujące | Brak duplikacji ani fantomowego odbioru |
| KB-16 | Zmiana wciśnięć blisko granicy wiersza/skanu | Brak częściowego skanu uznanego za poprawny pełny skan |
| KB-17 | Wszystkie 65 536 stabilnych masek 16 przycisków | Po pełnym geście: 16 masek jednoelementowych daje właściwe zdarzenie, pozostałe zero |
| KB-18 | Dowolny czas pracy / reset / flush | `row_oe` one-hot-or-zero, break-before-make, brak drive-high |

KB-17 uruchom na **RTL**, nie wyłącznie na modelu. Dla wydajności użyj skróconych poprawnych parametrów, skompilowanego harnessu lub batchowania i nie zapisuj VCD dla wszystkich masek. Nie skracaj odstępów tak, żeby ominąć synchronizator i czas skanu. Test pełnej macierzy ma osobny cel `test-exhaustive`; przed odbiorem projektu musi być uruchomiony i jego wynik zapisany. Domyślne parametry sprawdza dodatkowy krótszy test sprzętowych czasów.

### 4.3 Rejestry i PIN

| ID | Scenariusz | Warunek PASS |
|---|---|---|
| REG-01 | Każdy z 16 key_id | Poprawne mapowanie cyfr, `*` i klawiszy ignorowanych |
| REG-02 | Poprawny PIN, wszystkie pozycje pojedynczo błędne | Wybór GOOD/BAD zgodny z pełnym PIN-em |
| REG-03 | Błąd tylko ostatniej cyfry | Porównanie obejmuje nową cyfrę, brak błędu NBA |
| REG-04 | PIN z wiodącymi zerami, PIN_LEN=1/4/6/8 | Kolejność BCD i długość bez błędów szerokości |
| REG-05 | `*` po 0..PIN_LEN−1 cyfrach, #/A/B/C/D | Brak przypadkowego zatwierdzenia i inkrementacji |
| REG-06 | Pełny PIN i txn_ready=0 | Próba zliczona raz, txn_valid/payload stabilne |
| REG-07 | Wiele cykli valid dla jednej cyfry przy braku ready | Brak wielokrotnego dopisania tej samej cyfry |
| REG-08 | MAX_FAILS=1,3,4,7 | Blokada przy osiągnięciu limitu, nie o próbę później |
| REG-09 | Błąd → sukces → błąd | Sukces nie kasuje wcześniejszego błędu |
| REG-10 | Abort, timeout, `ena=0`, sesyjny reset | Licznik prób nie maleje |
| REG-11 | Zimny reset | Licznik i bufor wyzerowane wyłącznie według profilu demo |
| REG-12 | Osiągnięcie limitu i dodatkowe klawisze | Jedna ostatnia transakcja pozostaje ważna; nowe nie powstają |
| REG-13 | Zmiany wejść podczas BUSY/LOCKED | Wybór klucza nie zmienia się, nowy PIN nie jest składany |
| REG-14 | MAX_FAILS przy granicy szerokości, wiele zdarzeń po blokadzie | Brak zawinięcia licznika |
| REG-15 | Równe klucze, BCD zawierające A..F, PIN_LEN=0 | Odrzucenie niepoprawnej konfiguracji |
| REG-16 | PIN event/beep, pełny buffer i zakończenie | Zero pozostałości BCD po zatwierdzeniu / anulowaniu |

### 4.4 Szymon

| ID | Scenariusz | Warunek PASS |
|---|---|---|
| SIM-01 | Opublikowany KAT | Dokładnie `44c8fc20b9dfa07a` i właściwy porządek bitów |
| SIM-02 | Pełny ślad KAT | Zgodność każdego stanu po rundzie i kluczy rundowych z niezależnym modelem |
| SIM-03 | Co najmniej 1024 pary plaintext/key z zapisanym seedem | Wszystkie ciphertexty zgodne z modelem |
| SIM-04 | Zera, jedynki, naprzemienne bity, walking-one/zero w danych i kluczu | Poprawność skrajnych i pojedynczych bitów |
| SIM-05 | Przerwy między każdym z 64 wejściowych bitów | Stan przesuwa się tylko na s fire |
| SIM-06 | Brak seal po 64 bitach | Brak szyfrowania i brak m_valid niezależnie od czasu |
| SIM-07 | 63 bity i próba seal, 65. bit ze źródła respektującego ready | Brak przedwczesnego seal i brak przyjęcia dodatkowego bitu |
| SIM-08 | Backpressure na każdym bicie wyjściowym, także ostatnim | m_bit/m_last/m_valid stabilne, dokładnie 64 odbiory |
| SIM-09 | Zmiana cmd_key po starcie | Trwający blok nie zmienia klucza |
| SIM-10 | Reset/abort w LOAD, WAIT_SEAL, każdej rundzie, OUTPUT | Zero zaległych valid i danych, możliwy nowy blok po rearm |
| SIM-11 | Dwa kolejne bloki o różnych kluczach | Brak przeciekania stanu harmonogramu |
| SIM-12 | GOOD i BAD, skrajne i losowe dane | Ta sama latencja po seal fire: 1408 cykli dla `szymon`, 9344 dla `szymon_fixed` |
| SIM-13 | Monitor rund i kroków bitowych | 44×32 aktualizacje danych; w `szymon_fixed` dane stoją podczas dodatkowych kroków odtwarzania klucza |
| SIM-14 | Koniec rund 40..43 i końcowy TX | Zużyte klucze wyzerowane, po ukończeniu brak starego plaintext/ciphertext |
| SIM-15 | cmd_valid trzymane przy cmd_ready=0 | Brak przyjęcia drugiej transakcji w środku pierwszej |

Nie trzeba symulować wszystkich 2^192 kombinacji danych i klucza. Zgodność algorytmu wzmacniają opublikowany KAT, ślady, własności rund oraz niezależny model. Zapisz co rzeczywiście dowiedziono formalnie, a co pokryto symulacją.

### 4.5 Serial link

| ID | Scenariusz | Warunek PASS |
|---|---|---|
| SER-01 | RX 64 bity, unikalne wzorce skrajnych bitów | Bit 63 przychodzi pierwszy; wszystkie bity konsumowane raz |
| SER-02 | TX 64 bity | Pierwszy i ostatni bit prawidłowe, brak przesunięcia o 1 |
| SER-03 | Długości 0,1,63,64,65,127,128 | Akceptowane wyłącznie 64 bity w danej ramce |
| SER-04 | CS podniesione w połowie RX | Brak seal/obliczeń, kontroler dostaje błąd |
| SER-05 | 64 RX + dodatkowy bit przed końcem CS | Brak wcześniejszego seal, sesja odrzucona |
| SER-06 | CS w trakcie CRYPT i TX przed RSP_READY | Brak wyjścia stanu pośredniego |
| SER-07 | SCLK bez PIN-u albo CS=1 | Zero operacji, brak niezamówionego response |
| SER-08 | CS=0 przed uzbrojeniem | Wymagane świeże CS po stanie wysokim |
| SER-09 | Wstrzymanie transferu i granica timeout | Nie powstaje nowa sesja ani rollback próby |
| SER-10 | Różne fazy clk/sclk oraz minimalne legalne czasy | Poprawny odbiór bez zależności od fazy |
| SER-11 | Symulowany odbiorca RX czasowo not-ready | Pending valid stabilne, a rzeczywisty overrun daje abort, nie nadpisanie |
| SER-12 | Symulowany nadawca TX bez danych | Underrun daje abort, nie stary bit / dodatkowy wynik |
| SER-13 | Trzymane CS po 64. bicie TX | Brak dodatkowego m fire; RSP_READY utrzymane do końca/timeout |
| SER-14 | SDO przed TX, po TX, podczas CRYPT, reset i ena | Zawsze 0 poza dozwolonym oknem |
| SER-15 | Glitche mieszczące się w cyfrowym modelu i poza umową czasową | Zero nowego tokenu/PIN-u; nie deklarujemy poprawnego transferu poza specyfikacją |

### 4.6 Kontroler

| ID | Scenariusz | Warunek PASS |
|---|---|---|
| CTRL-01 | Brak dopuszczonego PIN-u, dowolny ruch sejfu | Zero cmd fire i zero REQ |
| CTRL-02 | GOOD i BAD w każdym położeniu licznika przed limitem | Właściwy klucz, jedna sesja, identyczny harmonogram dla tego samego ruchu |
| CTRL-03 | Zatwierdzenie ostatniego dozwolonego błędu | Dokończenie dokładnie tej jednej sesji; następne zabronione |
| CTRL-04 | Błąd po PIN-ie, przed RX, w RX, w CRYPT, w TX | Token znika, próba pozostaje zaliczona |
| CTRL-05 | Przedłużanie sesji pojedynczymi bitami / CS | Timeout jest absolutny, a nie odświeżany |
| CTRL-06 | Timeout i prawidłowy koniec na tym samym ticku | Priorytet zgodny ze SPEC, brak podwójnego session_end |
| CTRL-07 | Oczekiwanie na cmd/seal/bit ready | Brak deadlock wynikający z czekania valid na ready |
| CTRL-08 | Ponowna ramka bez ponownego PIN-u | Brak drugiego szyfrowania i response |
| CTRL-09 | Każdy stan + reset sesji / zimny reset | Właściwy zakres kasowania i bezpieczne piny |
| CTRL-10 | Skończona sesja i trzymany klawisz | Brak przypadkowej pierwszej cyfry następnego PIN-u |

### 4.7 Buzzer

| ID | Scenariusz | Warunek PASS |
|---|---|---|
| BZ-01 | Finalny ton pasywny, różne fazy trigger/ms_tick | Dokładnie określona liczba przyszłych ticków, bez off-by-one |
| BZ-02 | Trigger podczas busy, także na ostatnim ticku | Brak przedłużenia i kolejki dźwięków |
| BZ-03 | HALF_TICKS=1,2,3 | Prawidłowy półokres i liczba przełączeń |
| BZ-04 | Reset / ena podczas tonu | Wyjście 0, brak starego tonu po powrocie |
| BZ-05 | Poprawny i błędny PIN o tej samej długości/rytmie | Ten sam przebieg sterowania buzzerem |
| BZ-06 | Parametry brzegowe, BEEP=1 | Brak zerowej szerokości rejestrów i zawinięcia |

## 5. Integracja i wrapper TT

Wszystkie scenariusze end-to-end używają modelu elektrycznej klawiatury, rzeczywistych modułów i sejfu odczytującego piny.

| ID | Scenariusz | Warunek PASS |
|---|---|---|
| E2E-01 | Poprawny PIN + opublikowany challenge | Zgodność z KAT pod GOOD, licznik bez zmian |
| E2E-02 | Błędny PIN + ten sam challenge | Zgodność pod BAD; jedno zwiększenie przed REQ |
| E2E-03 | Błąd → sukces → błąd → ostatni błąd | Licznik 1,1,2,3; ostatni response BAD; dalsze PIN-y bez REQ |
| E2E-04 | Błędny PIN, sejf nie odpowiada | Timeout, błąd zachowany |
| E2E-05 | Ostatni błąd, potem urwanie kabla / RX / TX | Pozostaje LOCKED |
| E2E-06 | Dobry PIN, błędna ramka | Brak zwiększenia błędów PIN-u, potrzebny nowy PIN |
| E2E-07 | Dwa challenge po jednym PIN-ie | Maksymalnie jeden seal/ciphertext |
| E2E-08 | Chord/ghosting podczas każdej cyfry | Nie można w ten sposób złożyć poprawnego PIN-u |
| E2E-09 | Długie trzymanie cyfr i klawiszy specjalnych | Brak autorepeat / obejścia długości PIN-u |
| E2E-10 | `ena` znika przy działającym i zatrzymanym zegarze | Stan sesji znika, licznik błędów nie maleje |
| E2E-11 | Zimny reset po LOCKED | Powrót demo do stanu początkowego; wynik opisany jako ograniczenie |
| E2E-12 | Zmiana każdego nieużywanego wejścia | Żaden wynik/stan protokołu nie zależy od rezerwy pinów |
| E2E-13 | Wszystkie fazy protokołu | `uio_out=0`, `uio_oe[7:4]=0`, wiersze onehot0, unused outputs=0 |
| E2E-14 | Zmiana jednego bitu response, stara odpowiedź, brak aktywnego challenge | Sejf odmawia |
| E2E-15 | Wymuszona niejednoznaczność expected_good==expected_bad w mocku sejfu | Sejf odmawia, nie nadaje sukcesu |
| E2E-16 | Powtarzający się kandydat challenge w mocku RNG | Sejf nie używa go ponownie; timeout/restart nie akceptują zaległego response |
| E2E-17 | Losowe legalne sesje przeplatane błędami | Scoreboard wszystkich prób, tokenów i odpowiedzi pozostaje zgodny |
| E2E-18 | Realne domyślne wartości debounce i zegara | Co najmniej pełna udana sesja i pełna błędna sesja |

Co najmniej 256 losowych scenariuszy sesji z reprodukowalnymi seedami; część scenariuszy zaczyna się zimnym resetem, aby legalnie przetestować więcej niż trzy błędy. Test nie może niejawnie resetować DUT w każdym kroku i przez to zamaskować polityki prób.

## 6. Własności formalne

Minimalny zestaw harnessów SymbiYosys lub równoważnych. Parametry czasu można ograniczyć dla skończonego dowodu, zachowując semantykę. Założenia środowiska muszą być wypisane; nie zakładaj z góry tezy, którą chcesz udowodnić.

| ID | Własność |
|---|---|
| F-01 | Bez zimnego resetu fail_count nie maleje i nie przekracza MAX_FAILS |
| F-02 | Zwiększenie fail_count występuje tylko przy jednym zatwierdzeniu błędnego PIN-u |
| F-03 | Zablokowany układ nie dopuszcza nowej próby; istnieje wyjątek wyłącznie dla już dopuszczonej ostatniej transakcji |
| F-04 | Liczba rozpoczętych szyfrowań ≤ liczba dopuszczonych PIN-ów; jedna transakcja daje najwyżej jedno seal |
| F-05 | Bez poprawnego końca 64-bitowego RX nie ma seal |
| F-06 | Wszystkie kanały valid utrzymują payload przy backpressure, poza jawnym cancel/reset |
| F-07 | SDO jest 0 poza ramką TX; nigdy nie wysyłamy roboczego klucza ani stanu rund |
| F-08 | row_oe jest onehot0, uio_out stale 0, nieużywane wyjścia deterministyczne |
| F-09 | Po zaobserwowanym MULTI/zmianie kandydata nie ma key event do stabilnego puszczenia i nowego gestu |
| F-10 | Reset sesji/ena/timeout/abort nie zmniejszają licznika prób |
| F-11 | Wariant bitowy pojedynczej rundy po 32 krokach jest równoważny pełnosłowowej rundzie dla dowolnych wejść |
| F-12 | Aktualizacja jednego słowa klucza po 32 krokach jest równoważna pełnosłowowej formule |
| F-13 | Przy nieanulowanej sesji i działającym timebase aktywność kończy się poprawnie lub timeoutem w skończonym limicie |

Dla F-07 sprawdzaj źródło danych i dozwoloną fazę wysyłania: SDO może pochodzić tylko z zatwierdzonego, kompletnego ciphertextu. Nie formułuj błędnej asercji „ciphertext nigdy nie jest liczbowo równy kluczowi/stanu”: przypadkowa równość bitów nie oznacza wycieku, a taki zakaz nie wynika z szyfru.

Dla F-11/F-12 użyj arbitralnych wartości 32-bitowych i małego harnessu obejmującego 32 kroki; to silniejsza kontrola arytmetyki niż same losowe wektory. Jeżeli solver nie domyka dowodu, zapisz timeout / głębokość, zachowaj symulacje i nie zastępuj tego etykietą „formal PASS”. Cover potwierdza, że handshake, sukces, błąd i ostatnia próba są osiągalne — dowód bez osiągalnego ruchu może być pusty.

Nie wymagamy formalnego dowodu odporności kryptograficznej SIMON ani odporności fizycznej układu. Właściwości formalne dotyczą zaimplementowanego RTL i modelu środowiska.

## 7. Pokrycie, mutacje i regresja

Raport pokrycia ma obejmować moduły, stany FSM, przejścia, opcje parametrów i scenariusze funkcjonalne. Wymagamy wykonania wszystkich obowiązkowych scenariuszy i osiągnięcia wszystkich osiągalnych stanów/przejść; wyłączenia pokrycia wymagają komentarza. Pokrycie kodu raportuj liczbowo, nie ustanawiaj sztucznego 100% kosztem nieosiągalnych gałęzi konfiguracyjnych.

Wykonaj co najmniej pięć kontrolowanych mutacji w kopii roboczej/oddzielnym worktree: zamiana GOOD/BAD, usunięcie ostatniej rundy, przesunięcie wyjścia o bit, zerowanie prób przy abort, wyłączenie odrzucania chord. Każda musi spowodować FAIL konkretnego testu. Przywróć poprawny kod i pełną regresję. Nie zapisuj mutacji do finalnego RTL.

Wymagane cele przyszłego Makefile:

```text
make doctor           # wersje narzędzi, pliki i konfiguracja; bez fikcyjnego PASS
make lint
make test-model
make test-unit
make test-integration
make test-exhaustive
make test-params
make formal
make test-mutations
make synth
make harden
make test-gatelevel
make release-check
```

W `test-unit` istnieje możliwość wyboru pojedynczego modułu i seeda. `release-check` nie przechodzi przy NOT_RUN wymaganej kontroli. Brak narzędzia powoduje czytelny niezerowy kod wyjścia lub status BLOCKED interpretowany jako niezaliczenie, nigdy ciche pominięcie.

## 8. Gate-level i fizyka

Po syntezie/przejściu flow powtórz co najmniej KAT end-to-end, ścieżkę BAD, dojście do LOCKED, reset/ena, piny open-drain oraz krótki test ramki błędnej na rzeczywistym netliście z modelami wybranych komórek. Nie zastępuj netlisty RTL-em pod nazwą testu gate-level.

Gate-level bez SDF nie dowodzi timing closure. Osobno raportuj STA, setup/hold, zegary, unconstrained paths, DRC/LVS i pozostałe kontrole wymagane przez konkretny template. CDC false paths są dozwolone tylko do właściwych pierwszych stopni synchronizatorów; nie wyłączaj hurtowo analizy całego interfejsu ani rdzenia.

Przed użyciem fizycznej klawiatury potrzebne są pomiary poziomów, narastania kolumn, czasu ustalania po zmianie wiersza i prądu/połączenia buzzera. Symulacja grafu zwarć nie zastępuje tych pomiarów.

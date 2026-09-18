# Rumcajs — plan wykonania P0–P8

**Amendment 2026-09-12:** single-key behavior in [SINGLE_KEY.md](SINGLE_KEY.md)
replaces two-key/BAD-response/first-edge data-erasure requirements below.
The physical target remains IHP26b SG13G2 1x1, not SKY130.

## 1. Organizacja repozytorium

Poniższe ścieżki poza plikami planu mają zostać **utworzone przez Codexa**; nie istnieją jako gotowa implementacja w paczce. Zachowaj wymagane pliki oficjalnego template. Przykładowy układ:

```text
AGENTS.md
GOAL.txt
README_START.md
README.md                         # końcowa instrukcja projektu
info.yaml                         # zgodny ze schema wybranego template
src/
  project.v                       # tt_um_rumcajs
  rumcajs.v
  auth_ctrl.v
  kb.v
  regs.v
  szymon.v
  serial_link.v
  timebase.v
  buzzer.v
  sync2.v
  reset_release.v
model/
  simon64_128.py
  keypad_network.py
  protocol_model.py
  sejf_model.py
test/
  unit/                           # jeden bench/harness na każdy moduł
  integration/
  bfm/
  conftest.py / konfiguracja runnera
formal/
  harnessy.v / harnessy.sv
  *.sby
vectors/
  simon64_128_kat.json
scripts/
  check_parameters.py
  collect_metrics.py
  release_check.py
tools/
  verify_arithmetic_plan.py        # dołączony sprawdzony eksperyment arytmetyczny
docs/
  SPEC.md
  TEST_PLAN.md
  IMPLEMENTATION_PLAN.md
  SECURITY.md
  SOURCES.md
  ARITHMETIC_CHECK.md
reports/
  TARGET.md
  TOOLCHAIN.md
  PROGRESS.md
  DECISIONS.md
  BLOCKERS.md
  REQUIREMENTS.csv
  VERIFICATION.md
  AREA.md
  FINAL.md
Makefile
konfiguracja zależności Python / lockfile
.github/workflows/                # testy + rzeczywisty flow TT
```

Nowe raporty mają zaczynać z uczciwym stanem NOT_RUN, nie z przykładowymi wartościami PASS. `docs/info.md` i pozostałe dokumenty wymagane przez TT dopasuj do realnego template.

## 2. P0 — rozpoznanie środowiska i celu

Przeczytaj plan i obejrzyj bieżące repozytorium. Zidentyfikuj istniejący kod, branch, niezapisane zmiany i konfigurację Tiny Tapeout. Nie resetuj repozytorium do szablonu.

Ustal PDK i wersję flow na podstawie repozytorium, instrukcji organizatora lub istniejącego targetu. Gdy żadne z nich nie wskazuje technologii, wybierz **oficjalny SKY Verilog template jako roboczy benchmark**, zaznaczając brak potwierdzenia docelowego shuttle hackathonu. Istniejący poprawny IHP/GF target ma pierwszeństwo przed tym domyślnym wyborem. Dla innej technologii nie używaj wymiarów i limitów zaczerpniętych ze SKY [S3, S6].

W `reports/TARGET.md` zapisz: template URL i commit, PDK i wersję, nazwę biblioteki, rzeczywiste wymiary/marginesy tile'a, konfigurację 1×1, docelowy zegar, flow i aktywne parametry. Nie zgaduj nazw pól YAML. Sprawdź aktualne schema i przykłady. Osobno zapisz, czy target jest roboczy czy zatwierdzony do zgłoszenia.

Sprawdź narzędzia: Python/pytest/cocotb, Icarus Verilog lub Verilator, Yosys, narzędzie formalne z solverem, oficjalny flow TT i PDK. Zapewnij lokalne powtarzalne środowisko, przypnij faktycznie działające wersje. Nie zakładaj, że instalacja `apt` daje wersję zgodną z bieżącym flow. Instrukcje uruchomienia mają działać na Debianie; duże narzędzia mogą działać w przypiętym kontenerze zgodnym z oficjalnym template [S7].

**Odbiór P0:** zapisany target/toolchain, `make doctor`, spis blockerów, nieuszkodzona historia repo. Brak PDK nie blokuje tworzenia modeli i RTL, ale blokuje twierdzenie o dopasowaniu.

## 3. P1 — modele i zamrożenie interfejsów

Najpierw implementuj model pełnosłowowy SIMON i test jego opublikowanego KAT. Wygeneruj oczekiwania dla jawnego GOOD/BAD, różniących się kluczy i szeregu danych. Oczekiwania muszą wynikać z modelu, nie z DUT.

Zbuduj model elektryczny klawiatury i BFM SHIFT64. Przetestuj je samodzielnie. Przygotuj scoreboard prób i model sejfu. Sprawdź świeżość, jednorazowość i odrzucenie niejednoznaczności w jednostkowych testach sejfu.

Zapisz pełne tabele portów w `reports/INTERFACES.md`, w tym sygnał zatwierdzenia PIN-u do uruchamiania timeoutu, domeny resetów, cykl emisji valid i priorytety cancel. Zachowaj kontrakty SPEC; dodatkowe nazwy połączeń wewnętrznych można wybrać, ale przed równoległą pracą nad blokami muszą być zamrożone.

Zrób mały spike: bitowo-szeregowa runda i krok harmonogramu, ich zgodność z modelem i wstępna synteza 1-bitowego datapathu. Tego sprawdzenia nie odkładaj do ukończenia całego projektu.

**Odbiór P1:** KAT przechodzi w modelu, model matrycy uwzględnia ghosting, interfejsy są spójne, podstawowe testy modeli przechodzą.

## 4. P2 — minimalny rdzeń Szymon i wczesna powierzchnia

Implementuj pełny `szymon`: cmd, 64-bitowe ładowanie strumieniowe, seal, 44×32 kroki, strumieniowy output, abort i reset. Dane RX/rundy/TX muszą korzystać z tego samego 64-bitowego stanu. Parametry kluczy należą do regs, a szymon przyjmuje dowolne 128-bitowe `cmd_key` dla testowalności.

Uruchom SIM-01..SIM-15, porównania po każdej rundzie oraz formalne małe harnessy rundy i harmonogramu. Sprawdź szczególnie: orientację słów, Z/r, ostatni bit przed zamianą ról, 64. bit input/output oraz brak przyjęcia nowego cmd w busy.

Już teraz wykonaj syntezę rdzenia w docelowej bibliotece oraz wstępny flow dla minimalnego wrappera, jeśli PDK jest dostępny. Zapisz liczbę DFF, powierzchnię komórek, liczbę komórek, najdłuższą ścieżkę i konfigurację. Jeśli sam rdzeń zbliża się do limitu tile'a, zajmij się tym przed dopisywaniem peryferiów.

**Odbiór P2:** pełny szyfr przechodzi testy, kontrakt latencji jest sprawdzony, brak osobnych buforów blokowych; istnieje prawdziwy raport wstępnej syntezy lub jawny blocker PDK.

## 5. P3 — peryferia i stan PIN-u

Implementuj `reset_release`, `sync2`, `timebase`, `kb`, `regs`, `buzzer`, każdy z samodzielnym testbenchem. Zacznij od małych parametrów testowych, później potwierdź domyślne czasy.

W `kb` zbuduj najpierw poprawne skanowanie full-frame, potem kwalifikację gestu, poison wielokliku, emission po puszczeniu i pending ready–valid. Nie zaczynaj od 16 niezależnych liczników debounce. Przetestuj wszystkie pary i prostokąty, następnie uruchom pełne 65 536 masek.

W `regs` rozdziel reset licznika i reset sesji. Zdefiniuj atomowy punkt przyjęcia ostatniej cyfry, trwałość kontekstu przy txn_ready=0 oraz wyjątek dla ostatniej dozwolonej próby. Przetestuj wybrany PIN zaczynający się od zera i konfigurację PIN_LEN=1.

Buzzer implementuj jako stały generator tonu dla przetwornika pasywnego,
aktywny tylko w oknie timera. Nie dodawaj wyboru trybu, melodii ani dużej
pamięci dźwięków.

Można pracować równolegle nad `kb`, `regs` i `buzzer`, ale tylko po P1 i bez wzajemnego zmieniania kontraktów.

**Odbiór P3:** wszystkie testy jednostkowe peryferiów, wykrywanie mutacji wielokliku i rollbacku prób, brak błędów szerokości parametrów.

## 6. P4 — transport, kontroler i pierwsze end-to-end

Implementuj `serial_link` z framingiem i jednobitowymi pending/hold. Nie dodawaj pełnego modułu SPI IP, RAM-u ani FIFO blokowego. Sprawdź fizyczny porządek TX: sample przez sejf na rising, zmiana SDO przy falling. Przetestuj pending RX, CS przed PIN-em i nadmiarowy bit przed seal.

Zbuduj `auth_ctrl` z jednorazowym tokenem i absolutnym timeoutem. Połącz `rumcajs`, najpierw bez wrappera, potem z mapowaniem Tiny Tapeout. Stan próby jest zatrzaśnięty przed REQ; kontroler nie uzależnia czasu obliczeń od GOOD/BAD. Ostatnia dopuszczona błędna próba jest kończona zgodnie z jej tokenem, a nie odrzucana przez nowo ustawione locked.

Przeprowadź pełne demo: klawiatura → poprawny PIN → KAT response; błędny PIN → response BAD; trzecia błędna próba → jeden końcowy BAD → brak nowych sesji.

**Odbiór P4:** pierwsze pełne testy przez piny przechodzą, w repo są przebiegi demonstracyjne i driver sejfu.

## 7. P5 — regresja, formal i przegląd bezpieczeństwa

Uruchom całą macierz TEST_PLAN, parametry, wszystkie statyczne maski klawiatury, 1024 losowe wektory szyfru i co najmniej 256 losowych scenariuszy sesji. Zapisz realne czasy regresji i zoptymalizuj runner, nie zakres sprawdzania.

Domknij formalne własności F-01..F-13, opisując założenia i odróżniając pełny dowód od bounded check. Wykonaj cover dla realnych transferów, ostatniej próby i timeoutu. Jeżeli używasz modelu szyfru w harnessie kontrolera, zaznacz ten fakt i pokaż niezależną weryfikację rzeczywistego szyfru.

Sprawdź mutacje oraz wszystkie domeny resetu. Przejrzyj ścieżki, które mogłyby zużyć jedną poprawną autoryzację więcej niż raz. Zwróć uwagę na zgodność licznika po przerwaniu sesji, w przejściu TX_END i przy zmianie ena bez zegara.

**Odbiór P5:** wymagania mają przypisane dowody, testy nie są puste, niewykonane rzeczy nie są oznaczone PASS. Bez tego nie przechodź do ogłaszania MVP jako ukończonego.

## 8. P6 — optymalizacja powierzchni i rzeczywisty 1 tile

### Budżet roboczy, nie raport dopasowania

Najważniejszy koszt to pamięć, nie tylko bramki rundy. Naiwne osobne banki RX64 + TX64 + stan szyfru64 + harmonogram128 + PIN16 dają **336 bitów rejestrów** przed licznikami, synchronizacją i FSM. Wariant współdzielony ma **192 bity stanu szyfru** (64 dane +128 klucz), plus 16 bitów PIN-u i narzut sterowania. Nie doliczaj do niego dwóch banków stałych kluczy, jeśli naprawdę są parametrami kombinacyjnymi.

Dokumentacja TT podaje orientacyjnie około 320 DFF w pojedynczym tile przed uwzględnieniem potrzebnej logiki [S4]. To wskazówka, dlaczego duplikowanie buforów jest ryzykowne — **nie** gwarancja pojemności bieżącego tile'a w każdym PDK. Tak samo historyczne około 160×100 µm i „około 1000 bramek” nie zastępują wymiarów oraz raportu docelowego shuttle [S6].

### Kolejność optymalizacji

Najpierw mierz cały top, nie tylko Szymona. Usuń niepotrzebne kopie danych i nieużywane funkcje. Upewnij się, że stałe klucze nie stały się rejestrami, z nie jest rejestrem przesuwnym 62-bitowym, a użyta parametryzacja wycina generator tonu przy ACTIVE. Popraw szerokości liczników i dzielniki. W `kb` porównaj bitmapę z saturującą klasyfikacją full-frame. Nie kasuj semantyki poisoned gesture.

Potem porównaj kodowanie FSM i resetów/enable na tej samej bibliotece. Wielkie rejestry danych mogą mieć synchroniczne czyszczenie, a małe flagi valid/reset bezpieczeństwa inne komórki, o ile wszystkie kontrakty resetu i kasowania nadal przechodzą. Nie pozostawiaj tajnego stanu dostępnego przez SDO dla oszczędzenia resetu.

Dopuszczalne dodatkowe eksperymenty zachowujące pełny szyfr:

**Wariant A — bazowy:** 1-bit datapath z on-the-fly key schedule i 192 bitami stanu danych/klucza.

**Wariant B — stałe klucze:** generowany podczas budowania kombinacyjny ROM bitu klucza rundowego, indeksowany wyborem GOOD/BAD, rundą i pozycją bitu. Może usunąć 128 przerzutników harmonogramu, ale logika wyboru z tabeli 2×44×32 bitów może okazać się większa. To hipoteza do pomiaru. Źródłem stałych nadal mają być parametry `regs`; generator i RTL muszą mieć test sprawdzający zgodność dla różnych par kluczy. Nie wprowadzaj ręcznie utrzymywanej drugiej kopii sekretów. Interfejs testowy/adapter dla wariantu stałokluczowego opisz uczciwie; nie udawaj, że przyjmuje dowolny runtime key jak wariant A.

**Wariant C — inne złożenie datapathu:** wąski kilku-bitowy wariant lub inne współdzielenie liczników/resetów przy identycznym wyniku i protokole. Mierz, bo skrajna serializacja może wymagać kosztownych multiplekserów. Jeżeli zmienia się stała latencja, aktualizuj specyfikację i testy jawnie, bez uzależnienia od wartości PIN-u.

Nie zmieniaj na SIMON64/96, nie obniżaj liczby rund, nie wycinaj filtracji chord, nie przenoś poprawności do niezaufanego sejfu. Zmiana zakresu wymaga decyzji użytkownika. Zamiana cyfrowego debounce na elementy analogowe również nie jest automatycznym krokiem optymalizacji.

### Kryterium 1 tile

Uruchom właściwe hardening/place-and-route dla konfiguracji 1×1. Raport zawiera obszar core/tile, cell area, utilization według flow, DFF/cell counts, routing/congestion, slack setup/hold, drc/lvs i artefakty wymagane przez shuttle. Nie zwiększaj sztucznie do 100% dopuszczalnego upakowania, nie wyłączaj kontroli ani nie zmieniaj konfiguracji na 2 tile w finalnym teście 1 tile.

`FIT_1_TILE=PASS` wymaga rzeczywistego poprawnego wyniku flow. Sama synteza lub ekran „GDS created” bez kontroli końcowych nie wystarcza. Brak miejsca oznacza `FIT_FAILED`, nie ukryty fallback. Po pomierzonych sensownych wariantach A/B/C można przedstawić użytkownikowi blocker z najlepszym wynikiem i kosztem koniecznej zmiany; bez oznaczania celu jako osiągnięty.

**Odbiór P6:** pełny top mieści się w 1×1 w wskazanym PDK i przechodzi wymagane kontrole, albo istnieje jawny, poparty metrykami blocker.

## 9. P7 — netlista, CI i pakiet Tiny Tapeout

Uruchom gate-level smoke na realnej netliście. Powtórz istotne ścieżki sukces/błąd/limit/reset/ena i pinout. Zapisz, czy użyto SDF; brak SDF nie unieważnia smoke, ale nie jest dowodem timing closure.

Uzupełnij `info.yaml`, listę źródeł, dokumentację projektu, pinout, częstotliwość, hardware needed, instrukcję demo i ograniczenia. Zachowaj licencje i atrybucję autora/template. Nie wpisuj zmyślonych nazwisk i danych organizatora; pola wymagające tożsamości pozostaw do decyzji użytkownika i jawnie oznacz blocker zgłoszenia, nie blocker testów RTL.

CI ma uruchamiać szybkie testy na zmianach oraz pełne cele release (w tym exhaustive/formal i flow) w odpowiedniej konfiguracji. Repo musi dać się odtworzyć z czystego checkoutu na udokumentowanym środowisku. Nie polegaj na przypadkowych lokalnych plikach PDK.

**Odbiór P7:** działająca regresja i artefakty wersji finalnej, kompletny pakiet techniczny bez wykonywania samego zamówienia/zgłoszenia.

## 10. P8 — przegląd i Definition of Done

Wykonaj końcowy przegląd kodu oraz dokumentów. Sprawdź, czy wszystkie opisy odpowiadają rzeczywistemu RTL, zwłaszcza latencja, PIN auto-submit, zakres resetu, trzeci błędny response, ready–valid i kolejność bitów. Sprawdź, czy ograniczenie ulotności jest widoczne, a model sejfu nie korzysta z wnętrza DUT.

Końcowy `reports/FINAL.md` zawiera:

| Pole | Wymagany zapis |
|---|---|
| Commit i parametry | Dokładne identyfikatory |
| `RTL_DEMO` | PASS/FAIL + scenariusze demo |
| `VERIFICATION` | Wyniki jednostkowe, integracja, exhaustive, parametry, mutacje i formal |
| `FIT_1_TILE` | PASS/FAIL/BLOCKED, rzeczywiste metryki |
| `PHYSICAL_CHECKS` | STA/DRC/LVS oraz inne wymagane kontrole, osobno |
| `GATE_LEVEL` | Testy i rodzaj netlisty/timingu |
| `PRODUCTION_PERSISTENCE` | NOT_IMPLEMENTED — jawne ograniczenie zakresu |
| Sekrety i ataki fizyczne | Jawne demo, brak deklaracji ochrony produkcyjnej |
| Polecenie reprodukcji | Rzeczywiście działający zestaw komend |
| Otwarte problemy | Faktyczne pozostałe błędy, ograniczenia i decyzje |

**Zakończenie techniczne MVP**: gotowy Verilog, osobny testbench każdego modułu, wszystkie wymagane testy/dowody przechodzą, konfiguracja 1×1 przeszła rzeczywisty flow, dokumentacja i driver są odtwarzalne. To nie oznacza produkcyjnej trwałej blokady ani gotowości do ochrony rzeczywistego sejfu.

Brak narzędzi/PDK albo nieudany fit trzeba zgłosić jako blocker, zachowując już działające artefakty. Nie wykonywać nieskończonego losowego strojenia i nie deklarować ukończenia przez samo wypisanie propozycji kolejnych kroków.

## 11. Priorytety hackathonowe

Na początku najważniejsze są zamrożenie semantyki i wczesny pomiar szyfru. Następnie osobno peryferia, a możliwie szybko potem minimalne end-to-end. Równoległa praca nad testami modeli, kb i core ma sens po zamrożeniu interfejsów. Końcowej integracji, formalnych kontroli prób i PPA nie odkładaj na ostatnią godzinę.

Rozszerzenia UART/I2C/pełne SPI, bardziej złożone dźwięki, większy bufor zdarzeń i trwały backend pamięci nie należą do tego goal. Nie zaczynaj ich tylko dlatego, że chwilowo wolny jest jeden z wykonawców. Każde rozszerzenie zwiększa zakres weryfikacji i musi mieć własny cel po odbiorze MVP.

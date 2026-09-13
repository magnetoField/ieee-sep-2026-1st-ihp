# Rumcajs — specyfikacja normatywna 1.0

**Amendment 2026-09-12:** [SINGLE_KEY.md](SINGLE_KEY.md) supersedes the
two-key protocol, BAD responses, key-selection ports, READY pin definitions,
timer-start and immediate data-erasure requirements below. Those portions
are retained as historical v1.0 context, not current requirements.

## 1. Zakres, priorytety i konwencje

Rumcajs to demonstracyjny klucz uwierzytelniający challenge–response do Tiny Tapeout. Urządzenie zewnętrzne nazywamy **sejfem**. Sejf nie inicjuje uwierzytelniania samym zegarem interfejsu: najpierw użytkownik musi wprowadzić kompletny PIN. Dwa różne, współdzielone z sejfem klucze symetryczne odpowiadają poprawnemu i błędnemu PIN-owi.

Wymagany język syntezowalny: Verilog-2005. Moduły muszą być parametryzowane, ale nie trzeba obsługiwać dowolnego wariantu SIMON. Wspierany szyfr MVP jest jednoznacznie ustalony: SIMON64/128, pełne 44 rundy [S5]. Wartości czasowe i PIN można zmieniać parametrami; zmiana bezpieczeństwa lub semantyki protokołu wymaga jawnej decyzji.

Cel powierzchni to jeden tile 1×1. W pierwszej kolejności zachowujemy poprawność funkcjonalną; nie poświęcamy filtracji klawiatury, liczby rund ani kontroli ramek, aby uzyskać lepszy raport. Nie deklarujemy fizycznego dopasowania przed przejściem właściwego flow.

W tabelach `I` i `O` oznaczają kierunek względem opisywanego modułu. Wszystkie operacje logiczne są synchroniczne do dodatniego zbocza `clk`, poza jawnie opisanym asynchronicznym wymuszaniem resetu i bezpiecznych wyjść. `fire = valid && ready` na zboczu `clk`. Słowo „cykl” oznacza cykl `clk`, nie `sclk`.

## 2. Profil domyślny

| Ustawienie | Wartość | Znaczenie |
|---|---:|---|
| `CLK_HZ` | 1 000 000 | Częstotliwość dostarczana z zewnątrz; parametr nie generuje zegara |
| `SCAN_HZ` | 4000 | Tyle slotów wiersza na sekundę |
| Pełny skan | 1 ms | Cztery wiersze przy ustawieniach domyślnych |
| `PRESS_FRAMES` | 20 | Kolejne zgodne pełne skany wymagane do kwalifikacji naciśnięcia |
| `RELEASE_FRAMES` | 20 | Kolejne puste pełne skany wymagane do puszczenia / uzbrojenia |
| `PIN_LEN` | 4 | Liczba cyfr; wspierany zakres 1–8 |
| `PIN_VALUE` | `16'h1234` | Jawny PIN demonstracyjny, cyfry BCD od lewej |
| `MAX_FAILS` | 3 | Trzy błędy łącznie; blokada przy osiągnięciu, nie dopiero po przekroczeniu |
| `AUTH_TIMEOUT_MS` | 5000 | Absolutny limit sesji od zatwierdzenia PIN-u |
| `ACTIVE_BUZZER` | 1 | Domyślnie sterowanie zewnętrznym buzzerem z generatorem |
| `BEEP_TICKS_MS` | 50 | Liczba kolejnych ticków 1 ms trwania impulsu |
| `TONE_HALF_TICKS` | 1 | Dla pasywnego buzzera: półokres w tickach skanowania, domyślnie 2 kHz |
| Blokada | `DEMO_VOLATILE_LOCKOUT` | Reset globalny lub utrata zasilania nie zapewniają zachowania blokady |

`SCAN_DIV = CLK_HZ / SCAN_HZ` musi być całkowite i co najmniej 16. Dodatkowo `SCAN_HZ` ma być podzielne przez 1000, a dla skanowania 4×4 w MVP ustalone na 4000. Dopuszczalne jest uproszczenie interfejsu do stałego `SCAN_HZ=4000` i parametryzacji `CLK_HZ`. Parametry czasowe muszą być dodatnie. Rozmiar każdego licznika to minimum 1 bit. Parametry niepoprawne mają być odrzucane przez test elaboracji / kontrolę konfiguracji, a nie po cichu przycinane.

W testach można skracać liczby ticków debounce i timeout, ale konfiguracja produkcyjnego topa pozostaje oddzielna i przynajmniej jeden pełny scenariusz przechodzi z rzeczywistymi ustawieniami domyślnymi.

## 3. Piny Tiny Tapeout i sprzęt zewnętrzny

Interfejs zgodny z oficjalnym cyfrowym template: `ui_in[7:0]`, `uo_out[7:0]`, `uio_in[7:0]`, `uio_out[7:0]`, `uio_oe[7:0]`, `ena`, `clk`, `rst_n` [S2, S3]. Nazwa topa: `tt_um_rumcajs` — jeżeli wybrany shuttle wymaga dodatkowej unikalności, dodaj uzgodniony prefiks i zaktualizuj dokumentację.

| Port | Funkcja | Stan bezczynny / uwagi |
|---|---|---|
| `ui_in[3:0]` | `kb_col_n[3:0]` | Kolumny klawiatury, aktywne 0, cztery zewnętrzne pull-upy |
| `ui_in[4]` | `serial_sdi` | Dane challenge z sejfu |
| `ui_in[5]` | `serial_sclk` | Wolny zegar przesyłu z sejfu, stan spoczynkowy 0 |
| `ui_in[6]` | `serial_cs_n` | Granica ramki, stan spoczynkowy 1 |
| `ui_in[7]` | Nieużywany | Nie może wpływać na funkcję |
| `uio[3:0]` | `kb_row[3:0]` | Emulowane open-drain: tylko 0 albo Z |
| `uio[7:4]` | Rezerwa | Zawsze Z; nie mają funkcji debugowej |
| `uo_out[0]` | `REQ` | 1 przez aktywną sesję, od gotowości do RX do końca/abort |
| `uo_out[1]` | `RSP_READY` | 1 po przygotowaniu odpowiedzi, także podczas jej odczytu |
| `uo_out[2]` | `serial_sdo` | Dane odpowiedzi; 0 poza aktywną ramką TX |
| `uo_out[3]` | `buzzer_out` | Sterowanie zewnętrznym stopniem/buzzerem |
| `uo_out[7:4]` | Nieużywane | Zawsze 0 |

**Open-drain realizujemy przez `uio_oe`, nie przez `uo_out`.** Wszystkie bity `uio_out` są stale 0. Dla wybranego wiersza `uio_oe[i]=1`, dla pozostałych 0. Nigdy nie ma aktywnego sterowania stanem 1. Poza skanowaniem wszystkie wiersze są Z. Między wierszami obowiązuje co najmniej jeden cykl bez wysterowanego wiersza. W każdej chwili aktywnych jest najwyżej jeden wiersz.

Cztery wejścia kolumn wymagają rzeczywistych rezystorów podciągających na płytce. MVP nie zakłada dostępu do programowania pull-upów pada z RTL. `pullup` w testbenchu nie jest syntezowalnym zamiennikiem rezystora. Punkt wyjściowy do prototypu to cztery rezystory 10 kΩ do właściwego VDD_IO; dobór trzeba sprawdzić względem pojemności, czasu ustalania, napięć i wybranego PDK. Nie podłączaj wejść do 5 V na podstawie samych możliwości technologii — specyfikacja konkretnego demoboardu jest rozstrzygająca [S2].

Buzzer dostaje sygnał logiczny. Nie zakładaj, że pad zasili dowolny przetwornik. W dokumentacji połączeń uwzględnij odpowiedni tranzystor/driver, zasilanie i wspólną masę; dla obciążenia indukcyjnego także właściwe zabezpieczenie. Konfiguracja zewnętrznego mikrokontrolera nie może jednocześnie wymuszać sygnałów na kolumnach klawiatury.

## 4. Zegar, reset i `ena`

Nie używaj `always @(posedge serial_sclk)`. Wszystkie sygnały asynchroniczne danych przechodzą przez dwustopniową synchronizację. Dotyczy to czterech kolumn oraz SDI/SCLK/CS. Synchronizacja nie jest debounce ani gwarancją odporności na fault injection.

Rozdziel dwa rodzaje resetu:

**Reset zimny** pochodzi wyłącznie z `rst_n`. Zeruje licznik błędów w profilu demo. **Reset sesji** jest wymuszany przez `rst_n=0` lub `ena=0`; kasuje aktywny PIN i transakcję, ale nie licznik błędów. Dla obu stosuj asynchroniczne wymuszenie i synchroniczne zwalnianie, np. dwustopniowy `reset_release`. Reset sesji musi zostać zapamiętany także wtedy, gdy `ena` zniknie przy zatrzymanym `clk`: po ponownym uruchomieniu nie wolno wznowić starej transakcji.

W `regs` licznik prób i stan sesji muszą więc mieć rozdzieloną politykę resetu. Nie podłączaj resetu sesji do licznika prób. Logika i rejestry transakcji przechodzą do stanu bezpiecznego zanim po resecie sesji ponownie włączysz wyjścia.

Wyjścia maskuj warunkiem bezpiecznej aktywacji uwzględniającym `rst_n`, `ena` i zwolniony reset sesji: `REQ=0`, `RSP_READY=0`, `SDO=0`, buzzer=0, wiersze Z podczas resetu/dezaktywacji. Gdy zegar wróci, wyczyść także dane sesji. Wymagane minimum długości impulsu resetu/ena wynika z rzeczywistego sprzętu; subcyklowe impulsy poniżej specyfikacji i analogowe ataki zegarem nie są gwarancją MVP.

Reset zewnętrzny trzeba wymusić po włączeniu zasilania; nie opieraj funkcji ASIC na `initial` inicjalizującym przerzutniki. Przetestuj reset zatrzymanego zegara, wznowienie i brak samoczynnej odpowiedzi.

## 5. Kontrakty ready–valid

Źródło ustawia `valid` niezależnie od bieżącego `ready`. Przy `valid=1 && ready=0` utrzymuje `valid` i wszystkie bity payloadu bez zmian. Transfer zachodzi tylko na zboczu z `valid && ready`. Samo `ready=1` niczego nie konsumuje. Każdy zaakceptowany element ma dokładnie jednego odbiorcę i jest konsumowany raz.

Reset oraz jawny sygnał `abort`/`flush` są **anulowaniem transakcji** i stanowią zdefiniowany wyjątek od utrzymywania valid. Nie wolno samowolnie wycofać valid przy zwykłym backpressure. Testy monitorują stabilność także pól `last` i wyboru klucza, jeżeli należą do kanału.

`kb` używa 4-bitowych zdarzeń klawisza. `szymon` w docelowym wariancie używa **jednobitowych strumieni ready–valid** dla danych bloku. Ready–valid nie wymaga 64-bitowego payloadu. To celowa decyzja oszczędzająca osobne bufory RX i TX.

## 6. Moduł `timebase`

Wspólny dzielnik wytwarza jednocyklowe `scan_tick` i `ms_tick`, nie nowe zegary. Domyślnie `scan_tick` występuje co 250 cykli `clk`, a `ms_tick` co cztery takie ticki. Parametry i liczniki są sprawdzane na granicach, także gdy dzielnik jest potęgą dwójki.

`scan_tick` steruje przejściem między wierszami; `ms_tick` obsługuje timeout sesji i czas buzzera. W trybie tonu można wykorzystać `scan_tick` jako podstawę półokresu. Nie twórz trzech niezależnych dużych dzielników częstotliwości.

Tick globalny nie jest wyzerowany początkiem dowolnego timera. Dlatego czas „50 ms” buzzera oznacza wygaśnięcie na 50. przyszłym ticku ms i ma do 1 ms niepewności fazowej. Analogicznie timeout wygasa na 5000. przyszłym ticku. Testy liczą ticki, a dokumentacja podaje tę kwantyzację.

## 7. Moduł `kb`

### 7.1 Interfejs

| Kierunek | Sygnał | Znaczenie |
|---|---|---|
| I | `clk`, `rst_n` | Reset sesji, ze wspólną konwencją resetu |
| I | `enable`, `flush` | Zezwolenie na nowy gest; jawne anulowanie zdarzenia przy flush |
| I | `scan_tick` | Z `timebase` |
| I | `col_n[3:0]` | Wejścia kolumn; `kb` zawiera/instancjonuje ich synchronizator |
| O | `row_oe[3:0]` | Aktywne 1 oznacza ściąganie odpowiedniego wiersza do 0 |
| O | `key_valid`, `key_id[3:0]` | Jeden zaakceptowany klawisz |
| I | `key_ready` | Odbiorca odebrał numer klawisza |

`enable=0` zatrzymuje skanowanie (wszystkie wiersze Z), odrzuca niedokończony gest i rozbraja przyjmowanie kolejnego. Samo `enable=0` **nie wycofuje już wystawionego `key_valid`**: oczekujące zdarzenie trwa do handshake, resetu lub jawnego `flush`. Integracja przy anulowaniu sesji wystawia `flush`, zamiast polegać na ukrytym anulowaniu przez enable. Ponowne włączenie wymaga stabilnego puszczenia.

`key_id = 4*row + col`. `kb` nie interpretuje cyfry PIN-u ani klawiszy funkcyjnych. Mapowanie w `regs`:

```text
           col0 col1 col2 col3
row0         1    2    3    A
row1         4    5    6    B
row2         7    8    9    C
row3         *    0    #    D
```

### 7.2 Skanowanie i klasyfikacja

Po zwolnieniu resetu/flush/ponownym enable ignoruj trwające już naciśnięcie. Najpierw wymagaj `RELEASE_FRAMES` kolejnych pełnych skanów bez klawiszy. Dopiero potem uzbrajaj nowy gest.

W każdym slocie wysteruj jeden wiersz, odczekaj czas na ustalenie wejść i synchronizację, odczytaj kolumny. Zalecany porządek: przy końcu slotu pobierz próbkę starego wiersza; następnie wyłącz wszystkie wiersze na jeden cykl; dopiero potem włącz kolejny. Pierwsza próbka po resecie nie może udawać pełnej ramki. Slot musi zostawiać co najmniej ustalony margines synchronizacji; fizyczne RC muszą zdążyć przed próbką.

Pełny skan czterech wierszy klasyfikuj jako `NONE`, `ONE(id)` albo `MULTI`. Wystarczy akumulator liczby trafień nasycony do 2 i identyfikator pierwszego trafienia. Nie jest obowiązkowe przechowywanie bitmapy 16 bitów. Kilka trafień w jednym wierszu albo trafienia w różnych wierszach dają MULTI. Decyzja o pojedynczym klawiszu zapada dopiero po pełnym skanie.

### 7.3 Debounce i wieloklik

Gest zaczyna się od pierwszego zaobserwowanego naciśnięcia po uzbrojeniu. Zapisz kandydata. Do kwalifikacji wymagaj `PRESS_FRAMES` kolejnych pełnych skanów ONE z tym samym identyfikatorem. Krótkie puste skany przed kwalifikacją zerują licznik kolejnych trafień, ale nie pozwalają zamienić kandydata bez pełnego puszczenia.

**Zdarzenie key_valid emituj dopiero po puszczeniu:** po kwalifikacji naciśnięcia i `RELEASE_FRAMES` kolejnych skanach NONE. Długie trzymanie nie powoduje autorepeat.

Jeżeli od początku gestu do jego zakończenia pojawi się MULTI albo ONE z innym identyfikatorem, ustaw trwałą dla tego gestu flagę odrzucenia. Nawet jeśli użytkownik puści jeden z dwóch klawiszy, pozostały nie staje się poprawnym klawiszem. Odrzucony gest kończy się dopiero po stabilnym puszczeniu wszystkich przycisków; nie generuje zdarzenia.

Po emisji `key_valid` moduł ma pojedynczą pozycję bufora. Przy `key_ready=0` dane są stabilne dowolnie długo. Skanowanie może trwać, ale kolejnych gestów nie buforujemy. Po odebraniu zdarzenia ponownie wymagaj stabilnego pustego skanu, liczonego od tego momentu; przycisk wciśnięty w czasie zajętości nie może „przeskoczyć” do następnego PIN-u. `flush` kasuje bufor i uzbrojenie, co jest jawnym anulowaniem kanału.

Gwarancja dotyczy stanu zaobserwowanego podczas skanowania i przyjętych minimalnych czasów. Nie deklaruj wykrywania dowolnie krótkiego drugiego zwarcia między próbkami. Ghosting fizyczny modelujemy siecią połączeń; filtr odrzuca wieloklawiszowe gesty, nie identyfikuje wszystkich klawiszy w takiej sieci [S8].

### 7.4 Analogowy debounce

Nie należy w MVP zamieniać cyfrowego filtra na duży kondensator na kolumnie. Czas ładowania/rozładowania może przenosić stan między wierszami i zakłócić klasyfikację. Ewentualny wariant zewnętrzny wymaga analizy RC, czasu blankingu, progów wejścia i pomiaru oscyloskopem. Nie usuwa wymagań stabilnego puszczenia i odrzucania wielokliku.

## 8. Moduł `regs`: PIN, stałe, próby i kontekst

### 8.1 Własność stanu

`regs` zawiera stałe dwóch kluczy i poprawnego PIN-u oraz rejestry bieżących cyfr, liczby cyfr i liczby błędów. Klucze/PIN są parametrami stałymi przy elaboracji — **nie** dwoma dodatkowo ładowanymi bankami po 128 przerzutników. Wymagane jawne domyślne klucze demo:

```text
KEY_GOOD = 128'h1b1a1918131211100b0a090803020100
KEY_BAD  = 128'hf0e1d2c3b4a5968778695a4b3c2d1e0f
```

Klucze nie mogą być równe. Nie wyprowadzaj drugiego klucza prostą transformacją pierwszego. W produkcji wymagane byłyby niezależne klucze per urządzenie i inny provisioning; wartości tutaj są jawne i służą testom.

Proponowane porty poza zegarem/resetami: `key_valid/key_ready/key_id`, `txn_valid/txn_ready/txn_key_sel/txn_terminal`, `session_end`, `entry_enable`, `selected_key[127:0]`, `locked`, `beep_event`, `submit_event`. `submit_event` jest zdarzeniem zatwierdzenia ostatniej cyfry na tym samym zboczu co aktualizacja prób; może być sygnałem kombinacyjnym wyliczonym z key fire, dekodowania cyfry i licznika cyfr, aby kontroler rozpoczął timeout bez przesunięcia o tick. Nie jest drugim niezależnym sposobem zatwierdzania PIN-u. Sygnały stanu wewnętrznego mogą być obserwowane hierarchicznie w testbenchach, ale nie mają pinów debugowych.

### 8.2 Wprowadzanie PIN-u

Akceptuj tylko cyfry 0–9. Po każdej cyfrze aktualizuj pakowane BCD i licznik. Wiodące zera są pełnoprawnymi cyframi. `*` kasuje niekompletny PIN bez zaliczenia próby. `#`, A, B, C, D są w MVP ignorowane; nie zatwierdzają i nie obchodzą limitu.

PIN zatwierdza się automatycznie po `PIN_LEN`-tej cyfrze. Porównaj **wartość z dołączoną ostatnią cyfrą**, a nie poprzednią zawartość rejestru. Nie wykonuj wczesnego zakończenia porównania po pierwszej błędnej cyfrze. Dla danego zestawu parametrów czas ścieżki sterowania nie zależy od miejsca błędu.

„Jakikolwiek PIN” oznacza w tym MVP każdy kompletny ciąg `PIN_LEN` cyfr. Krótszy ciąg nie rozpoczyna sesji. Bufor częściowego PIN-u nie ma osobnego timeoutu w MVP; można go skasować `*`, resetem lub dezaktywacją `ena`.

### 8.3 Atomowe zatwierdzenie

Na zboczu odbierającym ostatnią cyfrę jednocześnie:

1. Ustal `pin_matches` na podstawie pełnego nowego BCD.
2. Zatrzaśnij `txn_key_sel` (1=GOOD, 0=BAD) i wynik `txn_terminal`.
3. Dla błędu zwiększ `fail_count` z nasyceniem do `MAX_FAILS`.
4. Zablokuj odbiór następnych cyfr, ustaw `txn_valid` i stan oczekiwania na koniec sesji.
5. Wyzeruj pakowane cyfry i licznik cyfr; do transakcji wystarcza zatrzaśnięty wybór klucza.

To zbocze jest **punktem zaliczenia próby**. Zdarzenie występuje raz, niezależnie od późniejszego `txn_ready`. Trzymanie `txn_valid` nie inkrementuje licznika ponownie. `txn_key_sel` i `txn_terminal` są stabilne aż do odebrania transakcji, a wybór klucza/kontekst pozostaje dostępny do zakończenia startu szyfru.

`REQ` może pojawić się dopiero później, gdy kontroler przygotuje odbiornik. Nie wolno wystawić REQ, a dopiero potem zaliczyć próbę.

### 8.4 Blokada

`fail_count` liczy wszystkie błędy od ostatniego resetu globalnego. Poprawny PIN **nie** zeruje licznika. `locked` jest równoważne osiągnięciu `MAX_FAILS`; licznik nie zawija się.

Dla `MAX_FAILS=3`: błąd 1 daje licznik 1, błąd 2 daje 2, błąd 3 daje 3 i blokuje przyjmowanie nowych prób. **Ta trzecia, już dopuszczona próba** nadal może otrzymać jeden challenge i oddać jeden response pod KEY_BAD. Kontroler musi honorować istniejący kontekst nawet jeśli `locked` już jest 1. Po ukończeniu, błędzie transmisji albo timeout tej próby pozostaje LOCKED. Nie można uzyskać kolejnego challenge po ponownym CS.

Błąd komunikacji nie jest błędem PIN-u. Nie zwiększa sam z siebie `fail_count`. Nie anuluje też wcześniej zaliczonego błędnego PIN-u. Poprawny PIN i uszkodzona transmisja nie zużywają limitu błędnych PIN-ów, lecz wymagają ponownego wprowadzenia całego PIN-u.

Klawisze, `ena=0`, timeout, `flush`, `abort` i `session_end` nie mogą zmniejszać licznika. Jedynym jego kasowaniem w demo jest zimny reset. Po LOCKED nie ma ścieżki serwisowego odblokowania przez protokół.

## 9. Moduł `szymon`: szyfr i wspólna pamięć danych

### 9.1 Zewnętrzny kontrakt bloku

Wymagane sygnały:

| Kierunek | Kanał / port | Znaczenie |
|---|---|---|
| I/O | `cmd_valid`, `cmd_ready` | Start nowego bloku, jedna transakcja naraz |
| I | `cmd_key[127:0]` | Klucz kopiowany do stanu harmonogramu tylko przy cmd fire |
| I/O | `s_valid`, `s_ready`, `s_bit` | Dokładnie 64 bity plaintextu, MSB first |
| I/O | `seal_valid`, `seal_ready` | Zatwierdzenie pełnego, poprawnie zakończonego RX |
| O/I | `m_valid`, `m_ready`, `m_bit`, `m_last` | 64 bity ciphertextu, MSB first; last dla bitu numer 63 |
| I | `abort` | Anulowanie bieżącej operacji i wyczyszczenie stanu danych |
| I | `clk`, `rst_n` | Reset sesji |

`cmd_ready` jest 1 wyłącznie w IDLE. `s_ready` jest 1 wyłącznie podczas przyjmowania pierwszych 64 bitów. Po 64. bicie nie przyjmuj 65. — gotowość spada. `seal_ready` jest 1 dopiero po złożeniu dokładnie 64 bitów. Bez `seal` szyfrowanie się nie rozpoczyna; to pozwala wykryć nadmiarowy bit ramki wejściowej przed użyciem szyfru.

`m_valid` nie może pojawić się przed ukończeniem wszystkich rund. Każdy m fire przesuwa wynik o jeden bit. Przy backpressure nic nie przesuwaj. Po 64. m fire blok wraca do IDLE; kontroler sesji nadal pilnuje końca ramki CS i nie daje nowego cmd. `abort` usuwa również oczekujące valid. Zmiana `cmd_key` po cmd fire nie wpływa na trwającą operację.

Dopuszczalny adapter 64-bit ready–valid do wygodnych testów, ale nie ma go w syntezowanym topie, chyba że pomiar wykaże wystarczające miejsce i korzyść. Adapter wymaga własnego testbencha.

Wariant ASIC `szymon_fixed` ma odrębny kontrakt czasowy: **9344 cykle**
od seal fire do pierwszego m_valid, tj. 9,344 ms przy 1 MHz. Odtwarza
pominięte parzyste klucze rundowe sekwencyjnie ze stałych punktów zapisu
co 32 rundy. Zachowuje wszystkie 44 rundy i 1408 aktualizacji danych,
ale w dodatkowych cyklach odtwarza klucz bez przesuwania danych. Czas jest
niezależny od plaintextu i wyboru GOOD/BAD. Opis 1408 cykli poniżej
pozostaje kontraktem modułu `szymon` z kluczem przekazywanym przy starcie.

### 9.2 Kolejność danych i KAT

Po odebraniu 64 bitów liczba plaintextu to `{x[31:0], y[31:0]}`, gdzie pierwszy przesłany bit jest bitem 63. W kluczu `k0=key[31:0]` jest pierwszym kluczem rundowym. Kolejne słowa startowe to `k1`, `k2`, `k3` rosnąco w słowie 128-bitowym.

Opublikowany test zgodności [S5]:

```text
key        = 1b1a1918131211100b0a090803020100
plaintext  = 656b696c20646e75
ciphertext = 44c8fc20b9dfa07a
```

Na drucie challenge ma bajty `65 6b 69 6c 20 64 6e 75`, każdy od MSB. Odpowiedź ma bajty `44 c8 fc 20 b9 df a0 7a`. To **zdefiniowana serializacja projektu**. Nie kopiuj bez konwersji tablic bajtów z implementacji C stosującej little-endian — opublikowany guide podaje również takie tablice.

### 9.3 Architektura bazowa: 1 bit/cykl

Przechowuj dane w dwóch 32-bitowych rejestrach A i B. Podczas RX tworzą jeden 64-bitowy rejestr przesuwny. Podczas szyfrowania są stanem Feistela. Podczas TX ten sam stan jest przesuwany na wyjście. Nie utrzymuj osobnych kopii challenge ani response.

Przechowuj harmonogram w czterech 32-bitowych rejestrach klucza. Generuj kolejne słowo w trakcie bieżącej rundy, nadpisując wykorzystane bity najstarszego słowa. Nie rozwijaj 44 kluczy do tablicy przerzutników. Stałą sekwencję z indeksuj z logiki stałej/ROM kombinacyjnego; nie używaj do niej 62 dodatkowych przerzutników.

Jedna runda trwa 32 cykle, 44 rundy dają **1408 cykli obliczeń**. To nie obejmuje odbioru, wysłania, handshake i opóźnień wrappera. Przy 1 MHz samo wykonywanie rund trwa 1,408 ms. Latencja nie zależy od danych ani wyboru klucza.

Przyjmij kontrakt: seal fire na zboczu t0; aktualizacje rund na kolejnych 1408 zboczach; pierwszy `m_valid=1` po zboczu t0+1408. Brak dodatkowego kroku zamiany słów po ostatniej rundzie. Gdy implementacja wymaga stałego dodatkowego kroku, najpierw zapisz zmianę tego kontraktu i zaktualizuj wszystkie testy — nie ukrywaj off-by-one przez luźny timeout.

### 9.4 Szczegół proponowanej arytmetyki bitowej

To propozycja mikroarchitektury sprawdzona arytmetycznie w dołączonym eksperymencie Python, a nie dowód poprawności przyszłego RTL.

Dla rundy r parzystej źródło X=A i cel Y=B; dla nieparzystej X=B i Y=A. W każdej rundzie przetwarzaj bity i=0..31 (od LSB). W danym cyklu:

```text
new_data_bit = (X[31] & X[24]) ^ X[30] ^ Y[0] ^ K0[0]
X_next       = rotate_right_1(X)
Y_next       = {new_data_bit, Y[31:1]}
```

Po 32 krokach X wraca do swej orientacji, Y zawiera nowe słowo. Zmień logiczne role A/B poprzez parzystość rundy, zamiast kopiować oba słowa. Po 44 rundach końcowy blok ponownie ma układ `{A,B}`.

Dla i-tego bitu nowego słowa klucza w rundach r=0..39:

```text
new_key_bit = K0[0] ^ K3[3] ^ K3[4] ^ K1[0] ^ K1[1]
              ^ (i >= 2) ^ ((i == 0) & Z[r])
Z = 64'hfc2ce51207a635db
```

K0 przesuwa się w prawo z `new_key_bit` wstawianym na MSB, a K1/K2/K3 rotują się w prawo o 1. W ostatnim kroku rundy **najpierw uwzględnij przesunięte wartości**, a następnie przypisz role `(K0,K1,K2,K3) = (rotated_K1, rotated_K2, rotated_K3, completed_new_word)`. Nie zgub ostatniego bitu przez użycie starych wartości NBA.

W rundach 40..43 nie potrzebujemy już nowych kluczy: wstawiaj 0 w zużywane K0, nadal rotując pozostałe słowa i zmieniając role. Po ostatniej rundzie ten wariant wyzeruje cały stan klucza. Test musi to potwierdzić; abort/reset również czyści klucz. Nie traktuj samego kasowania jako ochrony przed analizą poboru prądu.

W modelu referencyjnym użyj zwykłych pełnych słów, rotacji i rozwinięcia klucza, a nie powyższej sieci bitowej. Weryfikuj wynik po każdej rundzie i KAT. Pełne stałe zaszytych kluczy pozostają w `regs`, a stan harmonogramu należy do `szymon`.

## 10. `serial_link`: SHIFT64

### 10.1 Zakres

SHIFT64 to prosty punkt–punkt interfejs rejestru przesuwnego, bez adresów, opcodów i współdzielonej magistrali. Ma dwie osobne ramki CS: 64 bity challenge, potem 64 bity response. Nie reklamuj go jako kompletnego IP SPI/UART/I2C. Fizycznie korzysta z konwencji próbkowania podobnej do trybu SPI 0.

`serial_link` zawiera synchronizację wejść, detekcję zboczy, licznik bitów, framing i co najwyżej mały bufor jednobitowy. Nie zawiera osobnego 64-bitowego magazynu RX/TX. Kanał RX łączy bezpośrednio z `szymon.s_*`, a TX z `szymon.m_*` przez jednobitowe podtrzymanie SDO.

Porty sterowania od kontrolera mają jednoznacznie rozróżniać oczekiwanie na RX, RX, oczekiwanie na TX, TX, cancel. Zdarzenia w przeciwną stronę: poprawny koniec RX, koniec TX, błąd protokołu. Nazwy dodatkowych portów można wybrać podczas P1 i następnie zamrozić w tabeli interfejsów. Te zdarzenia nie mogą samodzielnie zmieniać licznika prób.

### 10.2 Czasy zewnętrzne

Wszystkie minimum dotyczą fizycznych pinów i okresu Tclk:

| Warunek | Minimum |
|---|---:|
| SCLK w stanie 1 | 16 × Tclk |
| SCLK w stanie 0 między bitami | 16 × Tclk |
| CS=0 do pierwszego zbocza narastającego | 16 × Tclk |
| Ostatnie opadające SCLK do CS=1 | 16 × Tclk |
| CS=1 pomiędzy ramkami | 16 × Tclk |
| SDI stabilne przed i po narastającym SCLK | 8 × Tclk w każdą stronę |

CS zmienia się wyłącznie przy SCLK=0. SDI najlepiej zmieniać na opadającym SCLK. Przy 1 MHz górna granica z tej umowy to 31,25 kHz SCLK. Driver demonstracyjny używa 10 kHz i odpowiednich przerw. Parametry fizyczne wybranego PDK / płytki muszą być sprawdzone niezależnie.

Dwustopniowa synchronizacja SDI/SCLK/CS wymaga tych czasów stabilności. Samo dodanie dwóch przerzutników do każdego sygnału bez założeń czasowych nie gwarantuje zachowania ich wzajemnego porządku. Testuj różne fazy względem `clk`. Bardzo krótkie impulsy poniżej tej umowy nie są obiecaną funkcją ani zabezpieczeniem fizycznym.

### 10.3 Sekwencja sesji

1. W spoczynku REQ=0, RSP_READY=0, CS=1, SCLK=0, SDO=0. Zegar lub ramka bez PIN-u nie uruchamiają szyfru.
2. Po zatwierdzeniu PIN-u `regs` zapisuje próbę i kontekst. Kontroler przekazuje cmd do szyfru, przygotowuje RX i dopiero wtedy podnosi REQ. Od tej chwili istnieje jeden nieodnawialny token transakcji.
3. Sejf po zauważeniu nowego REQ generuje świeży challenge, opuszcza CS i wysyła dokładnie 64 bity od bitu 63. Rumcajs odbiera na zaobserwowanych narastających SCLK.
4. Sejf podnosi CS. Dopiero prawidłowy koniec ramki 64-bitowej ze wszystkimi bitami odebranymi przez szymon uprawnia do seal. Nie wystarczy zobaczyć sam 64. bit.
5. Podczas szyfrowania sejf utrzymuje CS=1 i SCLK=0. Rumcajs utrzymuje REQ=1, RSP_READY=0, SDO=0. Przedwczesna nowa ramka CS jest błędem sesji.
6. Po przygotowaniu wyniku Rumcajs podnosi RSP_READY; REQ nadal jest 1. Sejf dopiero teraz opuszcza CS dla TX. Pierwszy bit odpowiedzi musi być gotowy przed pierwszym narastającym SCLK.
7. Sejf próbkuje 64 bity odpowiedzi na narastających SCLK. Rumcajs utrzymuje SDO do opadającego zbocza i przygotowuje kolejny bit na następną próbkę.
8. Po dokładnie 64 bitach i prawidłowym zamknięciu TX przez CS=1 kończy się sesja. REQ/RSP_READY/SDO wracają do 0. Nowa operacja zawsze wymaga nowego kompletnego PIN-u.

REQ to poziom aktywnej sesji, **nie zgoda na dowolną liczbę challenge**. RSP_READY pozostaje 1 do końca ramki TX, również po pobraniu ostatniego bitu z szymon, aby jego zakończenie nie zostało pomylone z początkiem kolejnej fazy.

Po przygotowaniu RX wymagaj zaobserwowanego CS=1 przed uznaniem nowego opadającego CS. CS utrzymane w 0 jeszcze przed PIN-em nie jest początkiem poprawnej ramki. Analogicznie nowa ramka TX musi mieć świeże zbocze po RSP_READY. Nie odtwarzaj starych zboczy zsynchronizowanych sprzed uzbrojenia.

### 10.4 Handshake bitów i framing

W RX przy narastającym SCLK złap SDI do jednobitowego kanału valid. Trzymaj bit do s fire. Jeżeli nadejdzie następny bit, gdy poprzedniego nie można odebrać, zgłoś overrun i anuluj sesję, nie nadpisuj danych. W poprawnym docelowym połączeniu `szymon` przyjmuje każdy z 64 bitów bez długiego backpressure. Zamknięcie CS jest poprawne tylko przy 64 odebranych bitach, braku overflow i opróżnionym pending RX. Czasy fizyczne dają margines na odebranie ostatniego bitu przed końcem CS.

W TX użyj `tx_hold`, aby nie zmieniać SDO w momencie konsumowania bitu przez szymon. Przed pierwszą próbką zatrzaśnij aktualny m_bit. Na zaobserwowanym narastającym SCLK wykonaj jedno m fire, a na opadającym przygotuj następny bit z nowego m_bit. Brak ważnego bitu w wymaganym momencie daje underrun/abort. Po 64. m fire nie konsumuj kolejnych bitów i oczekuj wyłącznie zamknięcia CS. Poza ramką TX SDO jest stale 0.

Ramki 0..63-bitowe i 65-bitowe lub dłuższe są błędne. Licznik nie zawija się z 63 na 0 i nie interpretuje nadmiaru jako nowej ramki. Dodatkowy bit RX przed CS=1 nie może uruchomić szyfrowania. Przy nadmiarowym bicie TX nie można cofnąć już wysłanych 64 bitów: wymaganie oznacza brak kolejnego response/ponownego użycia PIN-u i odrzucenie źle oprawionej odpowiedzi przez sejf, nie magiczne wycofanie informacji z drutu.

SCLK przy CS=1 oraz ramki w spoczynku bez aktywnej sesji ignorujemy. Przedwczesne CS podczas CRYPT, błędna długość, overrun, underrun lub timeout kończą aktywną sesję i usuwają jej dane. Żadne z nich nie cofa próby.

## 11. Moduł `auth_ctrl` i integracja `rumcajs`

`auth_ctrl` odpowiada za dopuszczenie jednej transakcji, wybór właściwego klucza z regs, start/abort szyfru, fazy SHIFT64, absolutny timeout, REQ/RSP_READY i zakończenie sesji. Nie interpretuje sam klawiszy i nie ma własnego licznika błędnych PIN-ów.

Zalecane stany semantyczne:

```text
IDLE -> START_CIPHER -> WAIT_RX -> RX -> SEAL -> CRYPT
     -> WAIT_TX -> TX -> WAIT_TX_END -> CLEANUP -> IDLE / LOCKED

aktywny stan + błąd/timeout -> CLEANUP -> IDLE / LOCKED
reset sesji -> skasowanie transakcji, próby zachowane
reset globalny -> reset demonstratora wraz z próbami
```

Dopuszczalne jest scalenie stanów przy zachowaniu wszystkich kontraktów. `LOCKED` może być reprezentowany warunkiem blokującym przyjmowanie PIN-u, ale nie wolno nim zdusić już dopuszczonej ostatniej błędnej próby. `regs.txn_terminal` rozstrzyga ten przypadek.

Timeout startuje od zatwierdzenia PIN-u, nie dopiero po pierwszym bicie. Nie restartuje go CS, kolejny bit ani przejście do TX. Pozostawiony w połowie transfer kończy się najpóźniej na `AUTH_TIMEOUT_MS`-tym przyszłym ticku ms. Gdy timeout i normalne zakończenie wypadają na to samo zbocze, przyjmij timeout jako priorytet; reset sesji ma priorytet nad obydwoma. Zaliczenie błędnej próby sprzed resetu sesji nigdy nie jest cofane.

Wyczyść stan roboczy szyfru, kontekst PIN-u, bufory linku i oczekujące zdarzenia klawiatury po zakończeniu i abort. Nowe wpisywanie zaczyna się dopiero po stabilnym puszczeniu klawiatury. Nigdy nie ustawiaj `key_ready` tak, aby połknąć cyfrę przeznaczoną już dla następnego PIN-u w cyklu przejścia do BUSY.

`rumcajs` jest testowalnym logicznym topem łączącym moduły. `tt_um_rumcajs` mapuje piny, kierunki i bezpieczne stany. Politykę resetów można umieścić w logicznym topie, aby dała się sprawdzić także bez wrappera TT. Oba poziomy mają oddzielne testy.

## 12. Moduł `buzzer`

Wejścia: `clk`, reset sesji, `ms_tick`, `scan_tick`, `beep_event`; wyjścia: `buzzer_out`, opcjonalnie wewnętrzny `busy`. `regs` emituje beep_event dla odebranej cyfry oraz `*` — jednakowo niezależnie od zgodności PIN-u. Klawisze ignorowane nie uruchamiają buzzera.

W trybie ACTIVE wyjście jest 1 przez `BEEP_TICKS_MS` przyszłych ticków ms. Ponowny trigger podczas busy jest ignorowany i nie przedłuża dźwięku. Trigger w tym samym cyklu co tick ma pierwszeństwo przy rozpoczynaniu z IDLE; trigger w cyklu kończącym busy nadal traktujemy jako zdarzenie podczas busy i ignorujemy.

W trybie pasywnym generuj przebieg prostokątny wyłącznie w tym samym oknie, przełączając fazę co `TONE_HALF_TICKS` scan_tick. Faza startuje od 0, a po końcu, reset lub ena=0 wyjście ma 0. Domyślny ACTIVE powinien usunąć niepotrzebny generator tonu w syntezie przez generate/stałą parametryzację.

Nie dodawaj różnych dźwięków dla poprawnego i błędnego PIN-u. Funkcja buzzera nie może zmieniać licznika prób ani blokować protokołu uwierzytelniania.

## 13. Wymagania po stronie sejfu

Powstaje niezależny model/driver Python, nie blok ASIC. Sejf zna oba klucze, ale Rumcajs nie przesyła mu PIN-u. Po nowym REQ sejf tworzy 64-bitowy challenge, zapisuje go jako jedyny aktualnie oczekujący i wysyła zgodnie z SHIFT64. Nie wyprowadza oczekiwanego response z wnętrza DUT.

Dla kompletnego, poprawnie oprawionego 64-bitowego response oblicza dwie wartości za pomocą niezależnego modelu:

```text
expected_good = SIMON64_128(KEY_GOOD, challenge)
expected_bad  = SIMON64_128(KEY_BAD,  challenge)
```

Zgodność tylko z GOOD oznacza poprawny PIN; tylko z BAD oznacza błędny PIN; brak zgodności oznacza błąd/odmowę. Teoretyczny przypadek zgodności z obydwoma oznacza **odmowę jako wynik niejednoznaczny**, nie sukces. Oba klucze są różne, ale same permutacje nie gwarantują różnych wyników dla każdego wejścia.

Każdy challenge ma co najwyżej jedno użycie i termin ważności. Po końcu sesji lub timeout usuń stan oczekiwania; spóźnione i ponownie odtworzone odpowiedzi są odrzucane. Sejf nie akceptuje niezamówionego response bez aktywnego challenge.

W testach używaj jawnego, powtarzalnego PRNG z seedem. W demonstratorze programowym poza testami użyj źródła losowego systemu, np. Python `secrets`, oraz kontroli powtórek. Nie utożsamiaj samego losowania 64 bitów z matematyczną gwarancją unikalności. Dla rozwiązania produkcyjnego świeżość, nieprzewidywalność, przechowanie stanu po restarcie i limit użyć klucza wymagają osobnego projektu. Rumcajs w tym MVP nie przechowuje historii challenge i nie uwierzytelnia sejfu [S9].

## 14. Parametry i rzeczy zabronione

Wspieraj PIN_LEN 1..8, poprawne BCD, różne klucze, MAX_FAILS co najmniej 1, dodatnie timery, oba tryby buzzera oraz konfiguracje testowe. Testuj MAX_FAILS 1, 3, 4, 7 i wartości wymagające zwiększenia szerokości licznika. Większe parametry mogą nie mieścić się w 1 tile; dowód fit dotyczy konkretnych udokumentowanych parametrów.

Nie obiecuj dowolnej parametryzacji szerokości SIMON: inne warianty mają inne rundy/sekwencje. Bez zgody nie zamieniaj SIMON64/128 na SIMON64/96, nawet jeżeli oszczędzi to rejestry. Nie używaj `initial` do zaszywania stanu startowego ASIC ani fałszywych makr NVM. Stałe kombinacyjne są dozwolone.

Implementację trwałego licznika pozostaw jawnie jako niezaimplementowane wymaganie produktu. Nie ma opcji konfiguracyjnej, która samą nazwą zmienia zwykłe DFF w pamięć nieulotną.

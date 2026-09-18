# Aktualny kontrakt: jeden klucz i jeden sygnał READY

Zmiana zakresu zatwierdzona przez użytkownika zastępuje wcześniejszy wariant
GOOD/BAD. Ten dokument ma pierwszeństwo przy sprzeczności ze starszym opisem
dwóch kluczy. Starsze materiały zachowano z oznaczeniem zakresu historycznego;
bieżące dowody i ograniczenia znajdują się w `../reports/SINGLE_KEY.md`.

- `KEY`: jeden 128-bitowy parametr szyfru. Pełny SIMON64/128, 44 rundy.
  Finalna wartość demonstracyjna to
  `128'hba2a1918131211100b0a090803020100`.
- Poprawny kompletny PIN dopuszcza dokładnie jeden challenge.
- Błędny kompletny PIN zwiększa licznik błędów, czyści PIN i ponownie
  uzbraja klawiaturę po stabilnym puszczeniu. Nie tworzy tokenu sesji,
  nie wystawia READY, nie przyjmuje challenge i nie szyfruje.
- Trzeci błędny PIN blokuje nowe próby. Nie ma końcowej odpowiedzi BAD.
  Sukces, timeout, abort i ena nie zerują licznika. Zimny reset nadal
  zeruje licznik demonstratora (ulotna blokada).

## Piny i protokół

`uo_out[0]` = **CHALLENGE_READY**: 1 dopiero po poprawnym PIN-ie i uzbrojeniu
odbiornika. Opada po rozpoczęciu RX; pozostaje 0 podczas obliczeń/TX,
po zakończeniu, błędzie protokołu lub timeout. To jedyny zewnętrzny pin
sygnalizujący gotowość. `uo_out[1]` jest rezerwą, stale 0.

`uo_out[2]` = odpowiedź szeregowa SDO; `uo_out[3]` = buzzer.
Piny SDI/SCLK/CS_n i klawiatury pozostają jak wcześniej. Wewnętrzny
`rsp_ready` służy kontroli i diagnostyce; nie jest wyprowadzony na pin TT.

Sejf czeka na CHALLENGE_READY, wysyła jedną ramkę 64-bitowego challenge,
MSB first, i kończy ją podniesieniem CS_n. Następnie czeka **10000 cykli
clk**, tj. 10 ms przy 1 MHz, po czym osobną ramką odczytuje 64-bitowy
ciphertext. Szyfr potrzebuje 9344 cykli od seal; reszta jest zapasem na
synchronizację i sterowanie. Przy innej częstotliwości należy przeliczyć
czas oczekiwania. Brak pinu RSP_READY oznacza, że protokół wymaga tego
stałego oczekiwania. Przedwczesna ramka podczas obliczeń anuluje sesję.

Timeout 5000 ms liczony jest od przyjęcia poprawnego PIN-u przez kontroler.
Błędny PIN nie otwiera sesji timeout. Nowy challenge wymaga kolejnego
poprawnego PIN-u; nie ma ponownego użycia tokenu.

## Finalny buzzer

`uo_out[3]` zawsze generuje nominalny ton 2 kHz dla buzzera pasywnego przez
50 ms. W finalnym topie Tiny Tapeout nie ma parametru ani wyboru trybu buzzera.
Wyjście wymaga odpowiedniego zewnętrznego drivera dla zastosowanego
przetwornika.

## Kasowanie zatwierdzone przez użytkownika

Po reset/abort rejestr danych przechodzi przez **64 cykle czyszczenia
szeregowego**. W tym czasie wszystkie ready/valid rdzenia są wyłączone,
wynik niewidoczny, a nowa komenda czeka. Sterowanie ma reset asynchroniczny,
więc także bez zegara wyjścia są bezpieczne; kasowanie danych kończy się
po powrocie zegara. Kolejny abort rozpoczyna 64-cyklowy okres od nowa.
Po pełnym TX rejestr jest już wyzerowany przez 64 przesunięcia zer.

READY ujawnia poprawność PIN-u — to zamierzone zachowanie nowego wariantu.
Publiczny klucz demo, brak odporności na ataki fizyczne i brak trwałej
blokady pozostają ograniczeniami. Nie używać do zabezpieczenia prawdziwego sejfu.

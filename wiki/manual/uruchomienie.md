# Pierwsze uruchomienie

Procedura dotyczy domyślnej konfiguracji D00RSH z zegarem **1 MHz** i PIN-em **1234**.

## Wymagany sprzęt

- Płytka udostępniająca interfejs Tiny Tapeout układu.
- Pasywna klawiatura matrycowa 4×4 i cztery rezystory podciągające kolumny.
- Host z liniami SDI, SCLK, CS_n oraz wejściami READY i SDO.
- Źródło zegara 1 MHz; opcjonalnie aktywny buzzer z odpowiednim driverem.

Połączenia opisuje [pinout](pinout.md). Dostosuj poziomy logiczne do płytki.

## Procedura

1. Podłącz klawiaturę, host i wspólną masę. Ustaw `CS_n = 1`, `SCLK = 0`.
2. Uruchom `clk = 1 MHz`, ustaw `ena = 1` i wymuś zimny reset `rst_n = 0`.
3. Zwolnij reset. Pozostaw działający zegar na czas kasowania danych i zwolnienia resetu. Klawiatura musi zobaczyć stabilne puszczenie wszystkich klawiszy, zanim przyjmie nowy gest.
4. Naciśnij i puść kolejno `1`, `2`, `3`, `4`. Dla wygodnego demo przytrzymuj klawisz około 50 ms i pozostaw około 50 ms przerwy po puszczeniu.
5. Poczekaj na `CHALLENGE_READY = 1`. Czwarta cyfra zatwierdza PIN; nie naciskaj `#`.
6. Wyślij 64-bitowy challenge zgodnie z [SHIFT64](protokol.md). Zakończ RX przez podniesienie CS_n.
7. Odczekaj **10 000 cykli CLK**, czyli 10 ms przy 1 MHz, z CS_n w stanie wysokim.
8. Otwórz nową ramkę i odczytaj dokładnie 64 bity SDO. Zamknij ramkę i porównaj wynik.

Kolejna transakcja wymaga ponownego wpisania poprawnego PIN-u.

## Wektor demonstracyjny

Wartości szesnastkowe; pierwszy przesyłany bit ma numer 63.

```text
PIN:        1234
KEY:        1b1a1918131211100b0a090803020100
CHALLENGE:  656b696c20646e75
RESPONSE:   44c8fc20b9dfa07a
```

To publiczny wektor testowy. Stałego challenge nie należy traktować jako zabezpieczenia przed ponownym użyciem odpowiedzi.

## Sprawdzenie błędnego PIN-u

Wpisanie innego pełnego czterocyfrowego PIN-u nie podnosi READY i nie daje odpowiedzi.
Po trzech błędnych PIN-ach nowe próby pozostają zablokowane. Zimny reset zeruje licznik demonstratora.

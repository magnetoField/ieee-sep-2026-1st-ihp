# Czasy i reset

W tabeli **Tclk** oznacza okres głównego zegara CLK. Dla 1 MHz: Tclk = 1 µs.
SCLK jest oddzielnym sygnałem interfejsu przesyłowego.

## Wymagania interfejsu

| Parametr | Minimum | Przy CLK = 1 MHz |
|---|---|---|
| SCLK w stanie wysokim | 16 × Tclk | 16 µs |
| SCLK w stanie niskim między bitami | 16 × Tclk | 16 µs |
| CS_n = 0 do pierwszego narastającego SCLK | 16 × Tclk | 16 µs |
| Ostatnie opadające SCLK do CS_n = 1 | 16 × Tclk | 16 µs |
| CS_n = 1 między ramkami | 16 × Tclk | 16 µs |
| Stabilność SDI przed narastającym SCLK | 8 × Tclk | 8 µs |
| Stabilność SDI po narastającym SCLK | 8 × Tclk | 8 µs |
| Od końca RX do rozpoczęcia TX | 10 000 × Tclk | 10 ms |

CS_n zmieniaj wyłącznie przy SCLK = 0. Powyższe minima ograniczają SCLK do
**31,25 kHz przy CLK = 1 MHz**. Driver demonstracyjny używa 10 kHz z wymaganymi
przerwami ramkowymi. Zmiana częstotliwości CLK wymaga uwzględnienia konfiguracji
układu; sama zmiana zegara nie zachowuje automatycznie czasów klawiatury i timeoutu.

## Czasy obsługi

| Funkcja | Konfiguracja domyślna |
|---|---|
| Pełny skan klawiatury | 1 ms |
| Kwalifikacja naciśnięcia / puszczenia | 20 / 20 pełnych skanów |
| Impuls buzzera | 50 przyszłych ticków 1 ms |
| Obliczenie szyfru po zatwierdzeniu RX | 9344 cykle CLK |
| Absolutny timeout sesji | 5000 przyszłych ticków 1 ms od przyjęcia poprawnego PIN-u |
| Kasowanie danych po reset/abort | 64 cykle CLK po zwolnieniu resetu/anulowania |

Timeout nie jest odświeżany przez bity lub ramki. Kwantyzacja czasu wynosi 1 ms;
timeout ma pierwszeństwo, jeśli wypada równocześnie z końcem transakcji.

## Reset i dezaktywacja

`rst_n = 0` wymusza zimny reset: usuwa kontekst sesji, częściowy PIN oraz
licznik błędów demonstratora. `ena = 0` anuluje sesję i częściowy PIN, ale zachowuje
licznik błędów. Reset należy wymusić po włączeniu zasilania.

Podczas resetu/dezaktywacji READY, SDO i BUZZER są w stanie 0, a wiersze klawiatury
w wysokiej impedancji. Maskowanie działa także przy zatrzymanym CLK.

**Kasowanie danych wymaga 64 cykli pracującego zegara.** Zwalnianie resetu dodaje
opóźnienie synchronizacji; nie traktuj 64 okresów od fizycznego zbocza rst_n jako
sygnału gotowości do pracy. Nowa sesja i tak wymaga świeżego PIN-u oraz READY.
Bez zegara kasowanie nie postępuje. Ponowne anulowanie rozpoczyna okres kasowania
od nowa. Powrót `ena = 1` nie wznawia starej transakcji.

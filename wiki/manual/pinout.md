# Podłączenie i pinout

Oznaczenia dotyczą **logicznych sygnałów Tiny Tapeout**, nie numerów nóżek obudowy.
Rozmieszczenie złączy zależy od użytej płytki.

## Sygnały

| Pin logiczny | Funkcja | Kierunek względem D00RSH | Uwagi |
|---|---|---|---|
| `ui_in[0]`…`ui_in[3]` | C0…C3 | wejście | Kolumny aktywne stanem 0, zewnętrzne pull-upy |
| `ui_in[4]` | SDI | wejście | Challenge z hosta |
| `ui_in[5]` | SCLK | wejście | Zegar przesyłu, spoczynek 0 |
| `ui_in[6]` | CS_n | wejście | Ramka aktywna stanem 0, spoczynek 1 |
| `ui_in[7]` | rezerwa | wejście | Bez funkcji |
| `uo_out[0]` | CHALLENGE_READY | wyjście | 1 tylko po poprawnym PIN-ie, przed RX |
| `uo_out[1]` | rezerwa | wyjście | Zawsze 0; brak pinu gotowości odpowiedzi |
| `uo_out[2]` | SDO | wyjście | Odpowiedź do hosta, poza TX stan 0 |
| `uo_out[3]` | BUZZER | wyjście | Sterowanie logiczne |
| `uo_out[7:4]` | rezerwa | wyjście | Zawsze 0 |
| `uio[0]`…`uio[3]` | R0…R3 | open-drain | Wybrany wiersz 0, pozostałe Z |
| `uio[7:4]` | rezerwa | wysoka impedancja | Zawsze Z |
| `clk` | CLK | wejście | Główny zegar 1 MHz |
| `rst_n` | RESET_n | wejście | Zimny reset aktywny stanem 0 |
| `ena` | ENABLE | wejście | 1: praca; 0: anulowanie sesji |

## Klawiatura

Każdą kolumnę C0…C3 podciągnij osobnym rezystorem do właściwego VDD_IO.
**10 kΩ jest wartością startową** do prototypu; końcowy dobór wymaga sprawdzenia
pojemności przewodów, czasów ustalania i poziomów wejść.

Wiersze R0…R3 są sterowane jako open-drain: układ zwiera wybrany wiersz do masy,
a pozostałe zwalnia. Nie wymuszaj na nich ani na kolumnach przeciwnego poziomu z hosta.
Zobacz [mapę klawiatury](klawiatura.md).

## Buzzer

Domyślnie wyjście steruje buzzerem aktywnym (z własnym generatorem).
Zastosuj zewnętrzny tranzystor lub driver, jeśli obciążenie tego wymaga.
Zapewnij wspólną masę i właściwe zabezpieczenie obciążenia indukcyjnego.

## Napięcia i zasilanie

Ta dokumentacja nie określa dopuszczalnych napięć padów ani prądu wyjściowego.
Sprawdź je dla konkretnej płytki i jej I/O. Nie zakładaj tolerancji 5 V.
Nie pozostawiaj używanych wejść w stanie pływającym. Nieużywane wejścia nie
wpływają na funkcję logiczną, ale ich podłączenie nadal powinno odpowiadać
zaleceniom płytki.

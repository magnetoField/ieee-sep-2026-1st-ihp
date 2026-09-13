# Protokół SHIFT64

SHIFT64 jest własnym synchronicznym interfejsem szeregowym. Host steruje SDI,
SCLK i CS_n oraz odczytuje CHALLENGE_READY i SDO. Nie zakładaj zgodności z dowolnym
trybem kontrolera SPI bez sprawdzenia [czasów](czasy.md).

## Przebieg transakcji

| Etap | READY | CS_n | Działanie hosta |
|---|---|---|---|
| Oczekiwanie na PIN | 0 | 1 | Bez transmisji |
| Autoryzacja | 1 | 1 | Przygotuj świeży challenge |
| RX | 0 po rozpoczęciu RX | 0 | Wyślij dokładnie 64 bity |
| Oczekiwanie na wynik | 0 | 1 | Odczekaj 10 000 cykli CLK po zamknięciu RX |
| TX | 0 | 0 | Odczytaj dokładnie 64 bity |
| Koniec | 0 | 1 | Zamknij ramkę; następny challenge wymaga nowego PIN-u |

## Ramka wejściowa

1. Poczekaj na READY, utrzymując CS_n = 1 i SCLK = 0.
2. Opuść CS_n i zachowaj co najmniej 16 cykli CLK przed pierwszym narastającym SCLK.
3. Wyślij challenge od bitu 63 do bitu 0. SDI jest próbkowane na narastającym SCLK.
4. Po ostatnim opadającym SCLK odczekaj co najmniej 16 cykli CLK i podnieś CS_n.

Prawidłowy koniec 64-bitowego RX dopuszcza obliczenie odpowiedzi.
CS_n musi wcześniej zostać zaobserwowane w stanie wysokim; ramka trzymana w stanie
niskim przed uzbrojeniem nie stanowi nowego rozpoczęcia.

## Oczekiwanie i ramka wyjściowa

Po zakończeniu RX odczekaj **10 000 cykli CLK**. D00RSH nie wystawia osobnego
sygnału gotowości odpowiedzi. Przy 1 MHz wymagane oczekiwanie wynosi 10 ms.

Opuść CS_n przy SCLK = 0. Po co najmniej 16 cyklach CLK rozpocznij 64 impulsy zegara.
Próbkuj SDO na zboczach narastających; następny bit przygotowywany jest po zboczu
opadającym. Pierwszy bit to bit 63 odpowiedzi. Zakończ ramkę tak jak RX.

## Błędy i ponowienie

Zbyt krótka lub zbyt długa ramka, przedwczesny TX i timeout anulują sesję.
Odrzuć częściową odpowiedź. Ponowienie wymaga nowego poprawnego PIN-u.
Sam błąd komunikacji nie jest błędnym PIN-em i nie zwiększa licznika prób.
Po anulowaniu obowiązuje okres [kasowania danych](czasy.md#reset-i-dezaktywacja).

## Obowiązki hosta

Host oblicza oczekiwaną odpowiedź jako `SIMON64/128(KEY, challenge)` i porównuje
wszystkie 64 bity. Musi odrzucić odpowiedź bez aktywnego challenge, niepełną,
niezgodną lub spóźnioną. Challenge powinien być świeży, jednorazowy i nieprzewidywalny.
D00RSH nie generuje challenge i nie przechowuje historii użytych wartości.

Demonstrator używa publicznego klucza, więc sam poprawny wynik nie dowodzi
posiadania konkretnego egzemplarza D00RSH. Zobacz [bezpieczeństwo](bezpieczenstwo.md).

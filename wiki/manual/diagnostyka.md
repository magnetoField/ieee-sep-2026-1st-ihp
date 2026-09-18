# Rozwiązywanie problemów

## Brak READY po wpisaniu PIN-u

Sprawdź zegar, `ena = 1`, zwolnienie resetu, pull-upy i [mapę klawiszy](klawiatura.md).
Każdą cyfrę należy nacisnąć i puścić. Przytrzymany lub wieloklawiszowy gest jest
odrzucany. Po trzech błędach demonstrator wymaga zimnego resetu.

Brak READY sam w sobie nie odróżnia błędnego PIN-u od blokady, zajętości czy resetu.

## Odpowiedź składa się z zer albo jest niepełna

Sprawdź, czy RX nastąpił po READY, obie ramki mają dokładnie 64 bity,
a od zakończenia RX do TX upłynęło 10 000 cykli CLK. Poza dozwoloną ramką TX SDO = 0.
Zerowa wartość danych nie jest osobnym kodem błędu protokołu.

## Wynik przesunięty o bit

Odczytuj SDO na narastającym SCLK. Zachowaj 16 cykli CLK od opuszczenia CS_n
do pierwszego zbocza. Pierwszy bit ma numer 63. Nie dodawaj wstępnego impulsu zegara.

## Klawisze są pomijane

Pozostaw stabilne naciśnięcie i puszczenie. Dla ręcznego demo stosuj około 50 ms
naciśnięcia i 50 ms przerwy. Sprawdź czas ustalania kolumn; nadmierna pojemność
może przenosić stan pomiędzy skanowanymi wierszami.

## Sesja znika

Powodem może być błędna ramka, zbyt wczesny TX, zmiana ena, reset lub upływ
absolutnego timeoutu około 5 s od poprawnego PIN-u. Odrzuć częściowy wynik,
przywróć spoczynkowe CS_n/SCLK i rozpocznij od nowego PIN-u.

## Buzzer nie wydaje dźwięku przy każdej cyfrze

Nowe zdarzenia podczas trwającego impulsu są ignorowane. Sprawdź również,
czy użyto buzzera pasywnego i drivera o odpowiedniej wydajności prądowej.
Wyjście generuje przebieg prostokątny o nominalnej częstotliwości 2 kHz.

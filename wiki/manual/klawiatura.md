# Klawiatura i PIN

## Mapa klawiszy

| Wiersz / kolumna | C0 | C1 | C2 | C3 |
|---|---|---|---|---|
| R0 | 1 | 2 | 3 | A |
| R1 | 4 | 5 | 6 | B |
| R2 | 7 | 8 | 9 | C |
| R3 | * | 0 | # | D |

## Wprowadzanie PIN-u

PIN demonstracyjny: **1234**. Każda cyfra jest przyjmowana dopiero po zakończeniu
poprawnego naciśnięcia i stabilnym puszczeniu klawisza. Czwarta cyfra automatycznie
zatwierdza PIN. Wiodące zera liczą się jako cyfry.

`*` usuwa niekompletny PIN bez zużycia próby. `#`, `A`, `B`, `C`, `D` są ignorowane.
Częściowy PIN nie ma osobnego timeoutu; można go skasować przez `*`, reset lub `ena = 0`.

## Filtr naciśnięć

Pełny skan czterech wierszy trwa nominalnie 1 ms. Filtr wymaga 20 kolejnych
zgodnych skanów naciśnięcia i 20 pustych skanów puszczenia. Są to liczby skanów,
więc dokładny czas od fizycznego zbocza zależy od fazy skanowania.

Długie trzymanie klawisza nie powoduje powtarzania. Zaobserwowany wieloklik
lub zmiana klawisza bez stabilnego puszczenia odrzuca cały gest. Po resecie,
anulowaniu lub zajętości trzeba puścić wszystkie klawisze przed nowym gestem.
Klawisz przytrzymany podczas sesji nie przechodzi automatycznie do następnego PIN-u.

## Limit błędnych prób {#limit-blednych-prob}

| Zdarzenie | Skutek |
|---|---|
| Poprawny pełny PIN | Jedna autoryzacja; wcześniejsze błędy pozostają |
| Pierwszy lub drugi błędny PIN | Licznik rośnie; brak READY i odpowiedzi; można próbować ponownie |
| Trzeci błędny PIN | Blokada nowych prób; brak końcowej odpowiedzi |
| Timeout, błąd transmisji, `ena = 0` | Licznik błędnych PIN-ów nie zmienia się |
| Zimny reset | Licznik zeruje się w profilu demonstracyjnym |

Nie ma osobnego wyjścia LOCKED ani portu odczytu licznika.

## Potwierdzenie dźwiękowe

Przyjęta cyfra lub `*` wyzwala impuls buzzera o nominalnym czasie 50 ms
(50 kolejnych ticków 1 ms, z niepewnością fazy do 1 ms).
Zdarzenie podczas trwającego impulsu nie przedłuża go i nie trafia do kolejki.
Dźwięk nie rozróżnia poprawnego i błędnego PIN-u.

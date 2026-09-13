# Instrukcje wykonawcze — Rumcajs

Aktualna zmiana zakresu użytkownika: jeden klucz, READY tylko po poprawnym
PIN-ie, błędny PIN bez challenge/odpowiedzi; zatwierdzone 64 cykle kasowania
po reset/abort. Kontrakt: `docs/SINGLE_KEY.md`. Ma pierwszeństwo nad starymi
wymaganiami dwóch kluczy, terminalnego BAD i natychmiastowego kasowania danych.

## Cel i kolejność źródeł

Implementuj działający i zweryfikowany projekt, nie tylko kolejną propozycję projektu. Najpierw przeczytaj `README_START.md`, `docs/SPEC.md`, `docs/TEST_PLAN.md`, `docs/IMPLEMENTATION_PLAN.md` i `docs/SECURITY.md`. Specyfikacja funkcjonalna ma pierwszeństwo przed przykładową organizacją kodu. Istniejące wymagania repozytorium i wskazany przez użytkownika PDK trzeba zachować. Istotną sprzeczność zgłoś, nie rozstrzygaj jej przez osłabienie zabezpieczenia.

## Zasady pracy

Pracuj etapami P0–P8. Po każdym etapie uzupełnij `reports/PROGRESS.md`: co uruchomiono, z jakim wynikiem, dokładna komenda, wersje narzędzi, ścieżki do logów, następny krok. Rejestruj decyzje w `reports/DECISIONS.md`, błędy i ograniczenia w `reports/BLOCKERS.md`. Dokończ możliwe prace niezależne od zablokowanego narzędzia.

Nie oznaczaj nieuruchomionego testu jako PASS. Nie podstawiaj symulowanych / przykładowych raportów zamiast wyników narzędzi. Brak PDK, narzędzia lub dostępu do CI oznacza BLOCKED/NOT_RUN, a nie zgodność z tapeoutem. Raport syntezy nie zastępuje place-and-route. Sprawdzenie modelu Python nie zastępuje sprawdzenia RTL.

Nie zmieniaj testu po to, aby zaakceptował błąd DUT. Model referencyjny szyfru ma mieć odmienną organizację niż bitowo-szeregowy RTL i musi przechodzić opublikowany KAT. Zachowuj seedy, komendy reprodukcji i minimalne scenariusze błędów. Kontrolowane mutacje krytycznych funkcji muszą być wykrywane przez testy.

Każdy dodany moduł syntezowalny ma mieć samodzielny testbench lub odrębny harness i jawny wiersz w macierzy weryfikacji. Dotyczy to również pomocniczych synchronizatorów, resetu, timerów i wrapperów. DUT: Verilog-2005. Testbench/harness: dopuszczalny SystemVerilog i cocotb/Python. Używaj jednego zegara `clk`, clock-enable zamiast zegarów z liczników; `sclk` jest wejściem danych do synchronizacji.

Oddziel bezpieczeństwo funkcjonalne RTL od odporności na ataki fizyczne. Nie opisuj profilu ulotnego jako trwałej blokady. Nie dodawaj atrap NVM, niezainicjalizowanych przerzutników jako „pamięci po resecie”, debugowego odblokowania ani portów odczytu kluczy/PIN-u. W publicznym repozytorium wolno używać wyłącznie jawnych kluczy demonstracyjnych.

## Optymalizacja

Priorytety: poprawność i nieosłabianie wymagań, następnie powierzchnia, następnie częstotliwość/latencja. Domyślna implementacja: pełne SIMON64/128, 44 rundy, 1 bit/cykl, wspólne 64 bity danych dla RX/szyfrowania/TX. Nie dodawaj osobnych 64-bitowych buforów bez pomiaru i uzasadnienia. Nie magazynuj wszystkich kluczy rundowych w przerzutnikach. Nie skracaj klucza, bloku, odpowiedzi, liczby rund ani filtracji wielokliku dla uzyskania 1 tile.

Nie dodawaj UART/I2C/rozbudowanego SPI przed zakończeniem MVP i oceną powierzchni. Nie zamieniaj debounce na kondensator bez analizy skanowania, czasów ustalania i testu sprzętowego. Porównania wariantów muszą używać tego samego PDK, ograniczeń i komitu narzędzi.

## Repozytorium i środowisko

Nie kasuj istniejących plików i nie cofaj pracy użytkownika. Zachowaj licencje i atrybucję oficjalnego template. Nie wykonuj push, zamówienia, płatności ani zgłoszenia do produkcji bez osobnej zgody. Nie zmieniaj globalnych uprawnień Codexa ani ustawień użytkownika. Nie wyłączaj sandboxa. Instalacje systemowe, uprzywilejowane kontenery i duże pobrania wymagają normalnej zgody; preferuj lokalne, przypięte środowisko.

Po wykryciu dostępnych wersji przypnij działający zestaw narzędzi. Nie zgaduj aktualnych nazw plików flow, wersji PDK ani workflow: sprawdź template wskazany w P0. Komendy Makefile w planie są wymaganym interfejsem projektu, który masz utworzyć, nie twierdzeniem o już istniejących komendach.

## Zakończenie

Oddzielnie raportuj `RTL_DEMO`, `VERIFICATION`, `FIT_1_TILE`, `PHYSICAL_CHECKS`, `PRODUCTION_PERSISTENCE`. Nie ogłaszaj celu osiągniętym przy FAIL/BLOCKED wymaganej weryfikacji lub dopasowania. `PRODUCTION_PERSISTENCE=NOT_IMPLEMENTED` jest jawnym ograniczeniem zakresu demonstratora, nigdy wynikiem PASS. Końcowy raport zawiera metryki, dowody, commit i pozostałe ryzyka.

# Layout i parametry fizyczne

## Render layoutu

<figure class="figure">
<a href="assets/chip-d6-layout.png"><img src="assets/chip-d6-layout.png" alt="Rzeczywisty render warstw layoutu D00RSH po routingu" width="1000" height="766"></a>
<figcaption>Rysunek 2. Końcowy layout D00RSH wygenerowany przez KLayout w flow LibreLane 3.0.5. Obraz 1000 × 766 px. To render projektu po place-and-route, nie mikrofotografia wyprodukowanego układu. Kliknij, aby otworzyć obraz.</figcaption>
</figure>

## Zmierzone parametry projektu

| Parametr | Wynik |
|---|---|
| Technologia | IHP SG13G2 / IHP26b |
| Format | Tiny Tapeout 1×1 |
| Obrys bloku | 202,08 × 154,98 µm |
| Powierzchnia komórek po syntezie | 20 944,7154 µm² |
| Liczba komórek po syntezie | 1318 |
| Powierzchnia komórek po routingu, bez fillerów | 25 996,7 µm² |
| Wykorzystanie obszaru komórek | 89,8251% |
| Zegar przyjęty do analizy | 1 MHz |
| Najgorszy zapas setup | +598,4245 ns |
| Najgorszy zapas hold | +0,0079368 ns |

Wymiary dotyczą bloku projektu, nie obudowy ani całego wspólnego układu Tiny Tapeout.

## Stan weryfikacji

Wyniki pochodzą z lokalnego raportu z 12 września 2026 r.; przebudowa wiki nie
stanowi ponownego uruchomienia testów układu.

| Obszar | Status |
|---|---|
| RTL_DEMO | PASS |
| VERIFICATION | PASS — lokalne wymagane testy, z kwalifikacjami raportu |
| FIT_1_TILE | PASS |
| PHYSICAL_CHECKS | PASS — STA, DRC, LVS i antena |
| Precheck Tiny Tapeout | 10/10 PASS |
| Funkcjonalny test netlisty po routingu | PASS bez SDF |
| Pełna symulacja SDF | UNSUPPORTED w użytym symulatorze |
| PRODUCTION_PERSISTENCE | NOT_IMPLEMENTED |
| Testy na krzemie / zgłoszenie do produkcji | Nie wykonano |

Analiza STA obejmuje trzy narożniki i określone ograniczenia czasowe. Pozostaje
15 ostrzeżeń fanout drzewa zegara oraz mały zapas hold; wyniki nie są pomiarami
analogowymi ani gwarancją odporności fizycznej.

Źródło danych: repozytoryjne raporty `reports/FINAL.md` i `reports/FULL_VERIFICATION.md`.
W chwili sporządzenia raportu nie istniał commit Git; tożsamość artefaktów zapisano
w manifeście SHA-256. Oryginalny render zachowano bez modyfikacji pikseli.

# Osiem pomysłów dla szymon_fixed — wyniki pomiarów

Wszystkie powierzchnie w µm². Punkt odniesienia: RTL SHA-256
`309d8fc5f7316ee6fd847dfd9289c5021765769ecfe01359d823e91b5196934e`,
rdzeń **10922,0454**, top **21817,0638**, szyfrowanie **9344 cykle**.
Yosys 0.52, ten sam IHP SG13G2 Liberty i area-first ABC co wcześniej.
Porównanie zachowuje listę i kolejność źródeł projektu, podmieniając tylko
szymon_fixed. Bez CTS, napraw hold, routingu i fizycznej akceptacji.

| Pomysł | Rdzeń | Cały top | Wynik |
|---|---:|---:|---|
| 1. 64 przerzutniki scan, SCD=Q, synchroniczny clear ma priorytet | 10800,3294 | 21935,3778 | Odrzucony: top rośnie o 118,3140 |
| 2. Wspólny clock gate | NOT_RUN | NOT_RUN | Niedopuszczony przez przypiętą konfigurację PDK; szczegóły poniżej |
| 3. Szeregowe czyszczenie 64 cykle | 10722,5370 | 21655,5066 | Oszczędza 161,5572 na topie, ale zmienia kontrakt; tylko eksperyment |
| 4. Schodzący group zamiast odejmowania key_depth | 10889,3862 | 21918,7836 | Odrzucony: top rośnie o 101,7198 |
| 5. Stała SPARSE_DELTA | 10916,4510 | 21922,2234 | Odrzucony: top rośnie o 105,1596 |
| 6a. Runda, następnie bit | 11248,9020 | 22076,2584 | Odrzucony |
| 6b. Bit, następnie runda | 11145,1410 | 21940,4430 | Odrzucony |
| 6c. Wspólna funkcja GOOD/BAD | 10943,7804 | 21851,8398 | Odrzucony |
| 7a. Pełna tablica, bez rekonstrukcji | 11212,0848 | 22375,6722 | Odrzucony; 1408 cykli |
| 7b. Punkty bazowe co 16 rund | 10943,7426 | 21922,3746 | Odrzucony; 5248 cykli |
| 7c. Punkty bazowe co 24 rundy | 10936,6362 | 21840,8022 | Odrzucony; 7808 cykli |
| 8. Z3 tylko dla używanych indeksów | **10713,4650** | **21668,4720** | **Zachowany: −208,5804 rdzeń, −148,5918 top** |

Sprawdzone połączenia: scan+Z3 = 10671,5826 / 21917,3472; group+Z3 =
10756,7838 / 21753,3330. Żadne nie poprawia całego topu względem samego
Z3. Dodatkowo izolowany delta+Z3 = 10738,6776, group+delta+Z3 =
10825,7310, scan+group+delta+Z3 = 10805,9238; odrzucone już na tym etapie.
Oszczędności nie są addytywne.

## Ograniczenia i interpretacja

1. W bazowej netliście są tylko cztery komórki mux2_1 w całym rdzeniu,
   nie 64 jawne pary DFF+mux2. ABC składa podtrzymanie i zerowanie z
   innych bramek. Wariant scan rzeczywiście zawiera 64 sdfrbpq_1; jego
   lokalna oszczędność nie przechodzi na top. Scan służy tylko do lokalnego
   podtrzymania Q: nie dodano portu skanowania ani ścieżki odczytu danych.
2. Yosys ma polecenie clockgate, lecz lgcp_1 ma `dont_use: true` i jest
   wymienione w **obu** plikach `synth_exclude.cells` i `pnr_exclude.cells`
   w `.tools/IHP-Open-PDK-partial/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/`.
   Nie wyłączono wykluczeń ani nie zbudowano zegara przez clk & enable.
   Dopuszczalność wymaga wyjaśnienia z opiekunem PDK/flow; rachunek 1134 µm²
   nie jest wynikiem testu ani obietnicą oszczędności.
3. Obecny RTL/test wymaga wymazania na pierwszym zboczu reset/abort.
   Eksperyment blokuje command/input/seal/output przez pełne 64 cykle,
   czyści tym samym łańcuchem i nie zeruje równolegle po TX. Nie włączono
   go do src; pytanie o zgodę na nowy kontrakt pozostaje do decyzji użytkownika.
   Nie uruchomiono jego pełnej integracji/formal/P&R. Stara asercja zakresu
   FSM wymaga rozszerzenia o ST_WIPE, jeśli wariant zostanie dopuszczony.
4. Group jest ładowany dla następnego bitu/rundy, a nie bezwarunkowo starą
   wartością round_count. Zachowany w eksperymencie alias key_depth służy
   tylko testom i znika w syntezie.
5. Mały lokalny zysk DELTA nie uzasadnia zachowania wariantu zwiększającego top.
6. Wspólna funkcja to jedna stała tablica indeksowana rundą, bitem i wyborem
   klucza; transpozycja zachowuje x w pominiętych słowach.
7. Pełna tablica usuwa maszynę rekonstrukcji, a nie dodaje 1152 przerzutników.
   Tutaj koszt większej logiki tablicy przewyższa oszczędność wynikającą
   z usunięcia maszyny rekonstrukcji: top jest większy o 558,6084.
8. Stała RECONSTRUCT_Z zawiera Z3[2*i−4] dla i=2..15 oraz 18..21.
   Pozostałe indeksy są nieistotne: akumulator zużywa Z3 tylko podczas
   odtwarzania parzystych rund 4..30 i 36..42. Sterowanie, liczba cykli,
   reset/abort oraz parametry kluczy nie zostały zmienione.

## Weryfikacja i reprodukcja

- Snapshoty RTL i skrypt pomiarowy: `.build/eight-ideas/` (lokalne artefakty,
  katalog ignorowany przez git; należy go zachować do odtwarzania prób).
- Komendy: `sh .build/eight-ideas/measure.sh VARIANT` oraz
  `sh .build/eight-ideas/measure.sh VARIANT tt_um_rumcajs`.
- Kanoniczne logi pomiarów: `reports/logs/eight-ideas/context-*.log`.
  Wstępne logi bez prefiksu context czytały tylko jeden plik RTL, dając
  nieco inne wyniki mapowania; nie mieszamy tych liczb z tabelą powyżej.
- Testy kierowane group, Z3 i scan+Z3: PASS na domyślnej parze kluczy,
  44 rundy, zużyte bity kluczy, dokładna latencja, data hold, 28 faz abort,
  rearm. Logi `test-group.log`, `test-z.log`, `test-scan_z.log`.
- Scan: użyty jawny model funkcjonalny równania Liberty bez SDF, nie
  sprawdzenie czasów komórki. Ponieważ wariant odrzucono, nie dodawano
  mapowania do finalnego flow ani nie deklarowano gotowości DFT/STA.
- Serial wipe: PASS na domyślnej parze dla zmienionego kontraktu, w tym
  brak gotowości przez 63 cykle i wyzerowanie/gotowość po 64., w 28
  pozycjach abort. `test-serial.log`; odrębny eksperymentalny testbench.
- Odrzucone warianty area-only nie mają deklarowanego funkcjonalnego PASS.

Do `src/szymon_fixed.v` włączono wyłącznie punkt 8. SHA-256:
`b1458d9a66f202704693c1882a0acaeee4573bcfd996734c2b9f33100d61b229`.
Latencja pozostaje 9344 cykle, 9,344 ms przy 1 MHz. Stan przed próbami
zachowano w `.build/eight-ideas/baseline.v`. Brak commitu (unborn main).

Zachowany wariant: `make lint`, `make test-unit MODULE=szymon_fixed`
(6 par kluczy), `make test-integration` (kierowane i 256 losowych sesji),
indukcja własności bezpieczeństwa i `make test-gatelevel`: PASS.
Logi: `accepted-regression.log`, `accepted-induction.log`,
`accepted-gatelevel.log`. Gate-level bez SDF; indukcja nie jest dowodem
pełnej równoważności kryptograficznej. Nie powtarzano niezwiązanych
wyczerpujących testów klawiatury, mutacji ani pełnego pokrycia.

Nie uruchomiono nowego P&R: oszczędność syntezy nie dowodzi usunięcia
poprzedniego błędu legalizacji 27 instancji. FIT pozostaje niezaliczony,
a historyczny przebieg fizyczny nie jest testem tej nowej wersji.

Update: the user subsequently authorized P&R. The Z3 RTL was run in
`runs/szymon_z_p80_h0`: synthesis 22523.0544 um2, CTS 24244.01 um2,
235 hold buffers, and detailed-placement failure on 9 instances. Thus
the retained optimization improves the prior physical result but does
not fit 1x1; routing/signoff and a final GDS were not reached. See
`PHYSICAL.md`.

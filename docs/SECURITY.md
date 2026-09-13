# Rumcajs — model zagrożeń i granice bezpieczeństwa

**Aktualizacja 2026-09-12:** obowiązuje [SINGLE_KEY.md](SINGLE_KEY.md).
Jeden klucz, błędny PIN bez odpowiedzi; READY celowo ujawnia poprawność PIN-u.
Opisy dwóch kluczy i symetrii GOOD/BAD poniżej są historyczne i nie stanowią
gwarancji aktualnego wariantu. Dane po reset/abort są niedostępne przez
interfejs, ale fizyczne zerowanie trwa 64 cykle; bez zegara nie postępuje.
Ulotność blokady, publiczny klucz demo i brak ochrony fizycznej pozostają.

## 1. Co jest projektowane

MVP ma wykazać poprawny cyfrowy przepływ: fizyczna klawiatura → jedno zatwierdzenie PIN-u → jeden challenge → jedna odpowiedź SIMON pod właściwym z dwóch kluczy. W tym modelu licznik błędnych PIN-ów nie jest cofany przez błąd transmisji, timeout ani dezaktywację `ena`. Testy obejmują niepoprawne sekwencje protokołu i obserwowalne wieloklawiszowe gesty.

To mechanizm z kluczami **symetrycznymi współdzielonymi**, nie podpis cyfrowy i nie para klucz prywatny/publiczny. Sejf z definicji posiada te same tajemnice co Rumcajs. Dwukluczowa odpowiedź przekazuje sejfowi kategorię PIN-u; sama w sobie nie uwierzytelnia sejfu wobec Rumcajsa.

## 2. Trwała blokada: wymaganie produktu pozostaje otwarte

Zwykły przerzutnik nie przechowuje informacji po utracie zasilania. Nie wolno twierdzić inaczej przez usunięcie resetu z always, użycie `initial`, pozostawienie rejestru X albo sztuczną pamięć w testbenchu. W standardowym planie cyfrowego projektu TT nie zakładamy dostępności makra OTP/eFuse/NVM. Oficjalna dokumentacja omawia pamięć opartą o DFF oraz rozwiązania zewnętrzne, co nie zapewnia tu automatycznie trwałego, chronionego licznika [S4].

MVP: `DEMO_VOLATILE_LOCKOUT`. Zimny reset kasuje licznik. Odłączenie zasilania i ponowny reset pozwalają rozpocząć demo od nowa. To jest **znane obejście względem wymogu „na zawsze”**, nie nieistotny szczegół. W finalnym README i raporcie musi być widoczne na początku sekcji bezpieczeństwa.

Aby zrealizować rzeczywistą trwałość, potrzebna jest technologia/architektura z chronionym monotonicznym stanem — np. zweryfikowane OTP/eFuse albo odpowiednio zabezpieczony komponent trwały. Zwykły zewnętrzny EEPROM lub plik na niezaufanym hoście nie zapewnia automatycznie odporności na cofnięcie zapisu, podmianę i odłączenie.

Protokół trwałego licznika musiałby najpierw bezpiecznie utrwalić zużytą próbę, a dopiero potem udostępnić skutki uwierzytelnienia. Zanik zasilania w połowie zapisu musi prowadzić do bezpiecznej odmowy, nie do odzyskania próby. Trzeba rozstrzygnąć rollback, atomowość, uszkodzenie zapisu, zużycie pamięci i uprawnienia do inicjalizacji. To osobny etap poza obecnym cyfrowym MVP.

## 3. Jawne stałe nie zapewniają poufności

Wartości kluczy i PIN-u w repozytorium to publiczne dane demo. Kto je zna, może obliczyć odpowiedź GOOD bez posiadania Rumcajsa i bez wpisywania PIN-u. Sam fakt wlutowania układu ASIC nie usuwa tej możliwości. Publiczny netlist/GDS także nie jest magazynem tajemnic.

Wersja użytkowa wymaga indywidualnych, niezależnych kluczy per urządzenie, chronionego provisioningu, ochrony odczytu oraz ustalonego sposobu wymiany/unieważniania kluczy. Nie umieszczaj rzeczywistych sekretów w plikach, commitach, logach testów ani materiale hackathonowym.

## 4. Challenge i replay

Challenge musi być świeży dla danego klucza, jednorazowy, ograniczony czasem i w rzeczywistym systemie również nieprzewidywalny. Ta ostatnia cecha ogranicza wcześniejsze zbieranie odpowiedzi dla przyszłych, przewidywalnych wyzwań. Sejf musi weryfikować odpowiedź tylko względem jednego aktualnego challenge; po zakończeniu usuwać kontekst i odrzucać replay. Znaczenie świeżych wyzwań dla odporności na powtórzenia opisuje NIST [S9]; Rumcajs nie deklaruje zgodności z całością tego standardu.

Losowe 64 bity nie gwarantują braku powtórek. Dla q niezależnych losowań i małego prawdopodobieństwa przybliżenie kolizji wynosi q(q−1)/2^65. To wynika z liczby par i przestrzeni 2^64. Przykładowo dla miliona losowań daje około 2,7×10^−8. W pobliżu 2^32 losowań ryzyko powtórzeń jest już duże. To ograniczenie rozmiaru wyzwania/bloku, a nie teza, że sam 128-bitowy klucz został złamany.

Długość odpowiedzi wynosi tylko 64 bity, więc nie wolno przedstawiać całego protokołu jako zapewniającego 128-bitowy poziom uwierzytelniania. Nie skracaj tej odpowiedzi jeszcze bardziej. Zmiana na większy blok albo standardowy mechanizm uwierzytelniania może być rozważona w późniejszym projekcie, ale nie może być cichą zmianą tego zadania.

Nie ma tutaj uwierzytelnienia sejfu, ochrony przed relay ani wiązania z tożsamością hosta/konkretną operacją. Użytkownik może więc nie wiedzieć, komu w rzeczywistości przekazuje odpowiedź. Demonstrator nie rozwiązuje tych zagrożeń.

## 5. Odpowiedź pod złym kluczem

KEY_GOOD i KEY_BAD muszą być różne i nie wolno wyprowadzać ich prostymi zależnościami. Znajomość KEY_BAD nie jest planowanym substytutem znajomości KEY_GOOD. Sejf porównuje obie oczekiwane wartości i rozróżnia odpowiedź GOOD, BAD, niezgodność i wynik niejednoznaczny.

Błędny PIN musi zużyć próbę przed wystawieniem REQ. W przeciwnym razie przerwanie transferu mogłoby być wykorzystane do nielimitowanych prób w określonych implementacjach. Trzymanie valid, brak CS, dodatkowe zegary lub zmiana `ena` nie mogą ponownie zaliczyć ani cofnąć tej samej próby.

Ostatnia dozwolona błędna próba może wysłać odpowiedź BAD, ale z chwilą zatwierdzenia ma już zużyty ostatni token. Zarówno normalne dokończenie, jak i urwanie tej sesji pozostawiają blokadę dla następnych PIN-ów.

## 6. Kanały boczne i ataki fizyczne

Taka sama liczba cykli i identyczne sygnały sterujące dla GOOD/BAD ograniczają prosty wyciek czasowy sterowania. **Nie** zapewniają stałego poboru prądu ani odporności na analizę mocy/EM, glitch zegara/resetu, fault injection, laser, odczyt struktury, sondowanie lub ekstrakcję klucza.

Bitowo-szeregowy rdzeń przetwarza tajne bity przez wiele cykli; jego mały rozmiar nie oznacza odporności fizycznej. Maskowanie i zabezpieczenia przed fault injection nie są częścią MVP. Zerowanie kluczy roboczych jest dobrą higieną stanu, nie dowodem usunięcia wszystkich kanałów bocznych.

Skanowanie klawiatury ma ograniczoną rozdzielczość czasową. Odrzucamy zaobserwowane gesty wieloklawiszowe, ale nie gwarantujemy wykrycia drugiego zwarcia dowolnie krótkiego i całkowicie między próbkami. Brak debounce w analogowym modelu też musi być jawny.

## 7. Odmowa usługi i fizyczny model zaufania

Trwałe blokowanie po trzech błędach z założenia umożliwia unieruchomienie urządzenia przez osobę mającą dostęp do klawiatury. To świadomy kompromis funkcjonalny, nie błąd do automatycznego „naprawienia” przez zerowanie prób po sukcesie. Timeout ogranicza czas zajętości transakcji, ale nie usuwa możliwości takiej odmowy usługi.

Dla demonstratora zakładamy prawidłowe zasilanie, spełnione minimalne czasy pinów, poprawne połączenia oraz jawne klucze testowe. Publiczne demo weryfikuje architekturę logiczną, nie nadaje certyfikatu ochrony rzeczywistego sejfu.

## 8. Obowiązkowa etykieta końcowa

Końcowy raport ma jawnie zawierać:

```text
Profil: demonstrator Tiny Tapeout
Blokada po błędach: ulotna, reset globalny / restart demo ją kasuje
Sekrety w RTL: publiczne wartości demonstracyjne
Odporność na ataki fizyczne: niezweryfikowana i niegwarantowana
Trwały licznik / provisioning produkcyjny: niezaimplementowane
```

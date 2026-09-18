# Bezpieczeństwo

IEEE DOORSH jest **demonstratorem funkcjonalnym**. PIN i klucz w tej wersji są publiczne.
Nie używaj tej konfiguracji do zabezpieczenia rzeczywistego sejfu lub danych produkcyjnych.

## Autoryzacja i licznik prób

Poprawny pełny PIN dopuszcza dokładnie jeden challenge. Błędny PIN nie wystawia
READY, nie dopuszcza challenge i nie daje odpowiedzi. Trzeci błąd blokuje dalsze próby.
Poprawny PIN nie usuwa wcześniej zaliczonych błędów.

Blokada jest **ulotna**: zimny reset zeruje licznik, a odłączenie zasilania
nie zapewnia zachowania stanu. Nie ma chronionej pamięci trwałej ani trwałej blokady.

## Informacje widoczne dla hosta

READY celowo ujawnia poprawność PIN-u. Buzzer potwierdza obsługę klawiszy,
ale nie rozróżnia wyniku PIN-u. Nie ma portów użytkowych do odczytu PIN-u i klucza.
Publiczny klucz umożliwia jednak obliczenie poprawnej odpowiedzi poza układem.

## Odpowiedzialność hosta

Host zapewnia świeżość challenge i weryfikuje pełną odpowiedź w aktywnej sesji.
Ponowne użycie challenge pozwala wykorzystać wcześniej zapisaną odpowiedź.
Jest to mechanizm symetryczny ze współdzielonym kluczem; nie jest podpisem cyfrowym
ani wzajemnym uwierzytelnieniem hosta i układu.

## Ograniczenia fizyczne

Nie deklaruje się odporności na odczyt fizyczny, analizę poboru prądu,
emisję elektromagnetyczną ani zakłócenia napięcia lub zegara. Kontrole cyfrowe
nie zastępują pomiarów klawiatury, padów i buzzera na rzeczywistej płytce.

Po reset/abort interfejs blokuje dostęp do danych, a kasowanie trwa 64 cykle
pracującego zegara. Zatrzymanie zegara wstrzymuje kasowanie.

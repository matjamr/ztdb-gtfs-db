Proponuję stworzenie systemu bazodanowego z minimalnym interfejsem użytkownika (UI), z backendem i podstawowym API typu CRUD, oraz na funkcjach monitorowania wydajności. System będzie służył do przechowywania, zapytań i modyfikacji danych związanych z infrastrukturą transportową, z możliwością przyszłej rozbudowy, oraz optymalizacją zapytań pod kątem efektywnego i sprawnego wyszukiwania połączeń.

Zakres projektu obejmuje:
	•   Wprowadzenie teoretyczne do baz danych relacyjnych (PostgreSQL), wektorowych (Neo4J) oraz standardu pliku GTFS (https://gtfs.org)
	•	Żródło danych: z danych GTFS -> KML autobusów (https://kolejemalopolskie.com.pl/pl/rozklady-jazdy/gtfs), MPK Kraków (https://gtfs.ztp.krakow.pl/).
	•	Wczytywanie danych: Skrypt lub proces automatycznego feedowania danych do bazy z plików lub API.
	•	Query:
		•	READ – odczyt danych (np. trasy, przystanki, czasy odjazdów)
		•	CREATE – dodawanie nowych rekordów
		•	UPDATE – modyfikacja istniejących rekordów
		•	DELETE – usuwanie rekordów
	•	Monitoring wydajności: Implementacja narzędzi lub mechanizmów do mierzenia czasu odpowiedzi i obciążenia zapytań.
	•	Deployment:
		•	Automatyzacja za pomocą Makefile
		•	Dockerizacja całego środowiska (backend, baza danych, ewentualnie UI, możliwa konfiguracja środowiska za pomocą minikube - kubernetesCLI)
	•	Front-end: Minimum 4 endpointy dla obsługi podstawowego interfejsu użytkownika (np. wyświetl, dodaj, edytuj, usuń).

Cel porównawczy:
Przeprowadzić testy i porównanie wydajności na zbiorze danych z KML autobusów a także danych MPK Kraków, aby ocenić różnice w czasie odpowiedzi i skalowalności przy różnych scenariuszach dla dwóch baz danych i dwóch minimalnie różnych podejść.
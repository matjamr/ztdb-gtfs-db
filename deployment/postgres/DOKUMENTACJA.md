# Dokumentacja Systemu GTFS - PostgreSQL

## Wprowadzenie

System wykorzystuje bazę danych PostgreSQL do przechowywania i przetwarzania danych GTFS (General Transit Feed Specification) - standardowego formatu danych o komunikacji publicznej. Baza danych umożliwia wyszukiwanie połączeń komunikacyjnych, rozkładów jazdy oraz planowanie podróży z uwzględnieniem przesiadek.

## Struktura Bazy Danych PostgreSQL

Poniżej znajduje się diagram ERD przedstawiający strukturę bazy danych:

<!-- Wklej tutaj diagram z draw.io: database_schema.drawio -->

---

## Tworzenie Struktury Bazy Danych

Struktura bazy danych jest tworzona przez skrypt `init.sql`, który wykonuje się automatycznie przy inicjalizacji kontenera PostgreSQL.

### Proces Tworzenia Tabel

#### 1. Usunięcie istniejących tabel (jeśli istnieją)

```sql
DROP TABLE IF EXISTS stop_times CASCADE;
DROP TABLE IF EXISTS trips CASCADE;
DROP TABLE IF EXISTS routes CASCADE;
DROP TABLE IF EXISTS stops CASCADE;
DROP TABLE IF EXISTS calendar CASCADE;
DROP TABLE IF EXISTS calendar_dates CASCADE;
DROP TABLE IF EXISTS shapes CASCADE;
DROP TABLE IF EXISTS agency CASCADE;
DROP TABLE IF EXISTS feed_info CASCADE;
```

#### 2. Tworzenie tabeli `agency` (Przewoźnicy)

```sql
CREATE TABLE agency (
    agency_id VARCHAR(255) PRIMARY KEY,
    agency_name VARCHAR(255) NOT NULL,
    agency_url VARCHAR(255) NOT NULL,
    agency_timezone VARCHAR(100) NOT NULL,
    agency_phone VARCHAR(50),
    agency_lang VARCHAR(10)
);
```

#### 3. Tworzenie tabeli `routes` (Trasy Linii)

```sql
CREATE TABLE routes (
    route_id VARCHAR(255) PRIMARY KEY,
    agency_id VARCHAR(255),
    route_short_name VARCHAR(50),
    route_long_name VARCHAR(255),
    route_desc TEXT,
    route_type INTEGER NOT NULL,
    FOREIGN KEY (agency_id) REFERENCES agency(agency_id)
);
```

**Relacja:** `routes.agency_id` → `agency.agency_id` (wiele tras należy do jednego przewoźnika)

#### 4. Tworzenie tabeli `stops` (Przystanki)

```sql
CREATE TABLE stops (
    stop_id VARCHAR(255) PRIMARY KEY,
    stop_code VARCHAR(50),
    stop_name VARCHAR(255) NOT NULL,
    stop_lat DECIMAL(10, 8) NOT NULL,
    stop_lon DECIMAL(11, 8) NOT NULL
);
```

#### 5. Tworzenie tabeli `calendar` (Kalendarz Kursowania)

```sql
CREATE TABLE calendar (
    service_id VARCHAR(255) PRIMARY KEY,
    monday INTEGER NOT NULL,
    tuesday INTEGER NOT NULL,
    wednesday INTEGER NOT NULL,
    thursday INTEGER NOT NULL,
    friday INTEGER NOT NULL,
    saturday INTEGER NOT NULL,
    sunday INTEGER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL
);
```

#### 6. Tworzenie tabeli `calendar_dates` (Wyjątki w Kalendarzu)

```sql
CREATE TABLE calendar_dates (
    service_id VARCHAR(255) NOT NULL,
    date DATE NOT NULL,
    exception_type INTEGER NOT NULL,
    PRIMARY KEY (service_id, date),
    FOREIGN KEY (service_id) REFERENCES calendar(service_id)
);
```

**Relacja:** `calendar_dates.service_id` → `calendar.service_id` (wiele wyjątków należy do jednego serwisu)

#### 7. Tworzenie tabeli `trips` (Kursy)

```sql
CREATE TABLE trips (
    trip_id VARCHAR(255) PRIMARY KEY,
    route_id VARCHAR(255) NOT NULL,
    service_id VARCHAR(255) NOT NULL,
    trip_headsign VARCHAR(255),
    direction_id INTEGER,
    shape_id VARCHAR(255),
    FOREIGN KEY (route_id) REFERENCES routes(route_id),
    FOREIGN KEY (service_id) REFERENCES calendar(service_id)
);
```

**Relacje:**
- `trips.route_id` → `routes.route_id` (wiele kursów należy do jednej trasy)
- `trips.service_id` → `calendar.service_id` (wiele kursów używa jednego serwisu kalendarzowego)

#### 8. Tworzenie tabeli `stop_times` (Czasy na Przystankach)

```sql
CREATE TABLE stop_times (
    trip_id VARCHAR(255) NOT NULL,
    arrival_time VARCHAR(8) NOT NULL,
    departure_time VARCHAR(8) NOT NULL,
    stop_id VARCHAR(255) NOT NULL,
    stop_sequence INTEGER NOT NULL,
    stop_headsign VARCHAR(255),
    pickup_type INTEGER,
    drop_off_type INTEGER,
    shape_dist_traveled DECIMAL(10, 2),
    timepoint INTEGER,
    PRIMARY KEY (trip_id, stop_sequence),
    FOREIGN KEY (trip_id) REFERENCES trips(trip_id),
    FOREIGN KEY (stop_id) REFERENCES stops(stop_id)
);
```

**Relacje:**
- `stop_times.trip_id` → `trips.trip_id` (wiele czasów należy do jednego kursu)
- `stop_times.stop_id` → `stops.stop_id` (wiele czasów dotyczy jednego przystanku)

**Klucz złożony:** `(trip_id, stop_sequence)` - unikalna kombinacja kursu i kolejności przystanku

#### 9. Tworzenie Indeksów dla Optymalizacji

```sql
CREATE INDEX idx_routes_agency ON routes(agency_id);
CREATE INDEX idx_trips_route ON trips(route_id);
CREATE INDEX idx_trips_service ON trips(service_id);
CREATE INDEX idx_stop_times_trip ON stop_times(trip_id);
CREATE INDEX idx_stop_times_stop ON stop_times(stop_id);
CREATE INDEX idx_calendar_dates_service ON calendar_dates(service_id);
CREATE INDEX idx_shapes_id ON shapes(shape_id);
CREATE INDEX idx_stops_location ON stops(stop_lat, stop_lon);
```

Indeksy są tworzone na kluczach obcych oraz na kolumnach używanych w zapytaniach (np. współrzędne geograficzne dla wyszukiwania przystanków).

---

## Ładowanie Danych GTFS

Dane GTFS są ładowane z plików CSV przez skrypt `load_gtfs.sql`. Proces importu odbywa się w następującej kolejności:

### Krok 1: Ładowanie danych przewoźników

```sql
COPY agency(agency_id, agency_name, agency_url, agency_timezone, agency_phone, agency_lang)
    FROM '/import/gtfs/agency.txt'
    DELIMITER ','
    CSV HEADER;
```

### Krok 2: Ładowanie tras linii

```sql
COPY routes(route_id, agency_id, route_short_name, route_long_name, route_desc, route_type)
    FROM '/import/gtfs/routes.txt'
    DELIMITER ','
    CSV HEADER;
```

### Krok 3: Ładowanie przystanków

```sql
COPY stops(stop_id, stop_code, stop_name, stop_lat, stop_lon)
    FROM '/import/gtfs/stops.txt'
    DELIMITER ','
    CSV HEADER;
```

### Krok 4: Ładowanie kalendarza kursowania

```sql
COPY calendar(service_id, monday, tuesday, wednesday, thursday, friday, saturday, sunday, start_date, end_date)
    FROM '/import/gtfs/calendar.txt'
    DELIMITER ','
    CSV HEADER;
```

### Krok 5: Ładowanie wyjątków w kalendarzu (opcjonalne)

```sql
DO $$
    BEGIN
        COPY calendar_dates(service_id, date, exception_type)
            FROM '/import/gtfs/calendar_dates.txt'
            DELIMITER ','
            CSV HEADER;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'calendar_dates.txt not found or empty, skipping...';
    END $$;
```

Używa bloku `DO` z obsługą wyjątków, ponieważ plik może nie istnieć.

### Krok 6: Ładowanie kształtów tras (opcjonalne)

```sql
DO $$
    BEGIN
        COPY shapes(shape_id, shape_pt_lat, shape_pt_lon, shape_pt_sequence)
            FROM '/import/gtfs/shapes.txt'
            DELIMITER ','
            CSV HEADER;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'shapes.txt not found or empty, skipping...';
    END $$;
```

### Krok 7: Ładowanie kursów

```sql
COPY trips(route_id, service_id, trip_id, trip_headsign, direction_id, shape_id)
    FROM '/import/gtfs/trips.txt'
    DELIMITER ','
    CSV HEADER;
```

### Krok 8: Ładowanie czasów na przystankach (największy plik)

```sql
COPY stop_times(trip_id, arrival_time, departure_time, stop_id, stop_sequence, stop_headsign, pickup_type, drop_off_type, shape_dist_traveled, timepoint)
    FROM '/import/gtfs/stop_times.txt'
    DELIMITER ','
    CSV HEADER;
```

To zwykle największy plik w zestawie danych GTFS, zawierający wszystkie czasy przyjazdu i odjazdu dla wszystkich kursów.

### Krok 9: Weryfikacja zaimportowanych danych

```sql
SELECT 'agency' as table_name, COUNT(*) as row_count FROM agency
UNION ALL
SELECT 'routes', COUNT(*) FROM routes
UNION ALL
SELECT 'stops', COUNT(*) FROM stops
UNION ALL
SELECT 'calendar', COUNT(*) FROM calendar
UNION ALL
SELECT 'calendar_dates', COUNT(*) FROM calendar_dates
UNION ALL
SELECT 'shapes', COUNT(*) FROM shapes
UNION ALL
SELECT 'trips', COUNT(*) FROM trips
UNION ALL
SELECT 'stop_times', COUNT(*) FROM stop_times
UNION ALL
SELECT 'feed_info', COUNT(*) FROM feed_info
ORDER BY table_name;
```

---

## Zapytania SQL

Poniżej znajdują się szczegółowe opisy i diagramy działania dla każdego zapytania SQL w systemie.

### Query 1: Wyszukiwanie tras obsługujących dany przystanek w określonym dniu

**Czas wykonania:** 141 ms ⚡

**Cel:** Znajduje wszystkie linie komunikacyjne, które obsługują wskazany przystanek w danym dniu, wraz z liczbą kursów.

<!-- Wklej tutaj diagram z draw.io: query1_diagram.drawio -->

---

### Query 2: Rozkład odjazdów z przystanku w danym dniu

**Czas wykonania:** 112 ms ⚡

**Cel:** Wyświetla szczegółowy rozkład jazdy - wszystkie odjazdy z danego przystanku w określonym dniu, posortowane według czasu odjazdu.

<!-- Wklej tutaj diagram z draw.io: query2_diagram.drawio -->

---

### Query 3: Bezpośrednie połączenie (bez przesiadki)

**Czas wykonania:** 463 ms ⚡

**Cel:** Znajduje bezpośrednie połączenia między dwoma przystankami (ten sam pojazd, bez przesiadki).

<!-- Wklej tutaj diagram z draw.io: query3_diagram.drawio -->

---

### Query 4: Połączenie z jedną przesiadką

**Czas wykonania:** 22 s ⏱️

**Cel:** Znajduje połączenia wymagające jednej przesiadki między dwoma przystankami, z możliwością przesiadki na pobliskim przystanku (do 500m).

<!-- Wklej tutaj diagram z draw.io: query4_diagram.drawio -->

---

### Query 5: Odkryj wszystkie trasy z liczbą kursów

**Cel:** Wyświetla wszystkie linie komunikacyjne wraz z liczbą kursów i typem pojazdu.

<!-- Wklej tutaj diagram z draw.io: query5_diagram.drawio -->

---

### Query 6: Znajdź najbardziej ruchliwe przystanki

**Cel:** Wyświetla przystanki z największą liczbą kursów dziennie.

<!-- Wklej tutaj diagram z draw.io: query6_diagram.drawio -->

---

### Query 7: Wzorzec częstotliwości dla przystanku

**Cel:** Pokazuje liczbę odjazdów na godzinę dla danego przystanku z kategoryzacją częstotliwości.

<!-- Wklej tutaj diagram z draw.io: query7_diagram.drawio -->

---

### Query 8: Znajdź węzły przesiadkowe

**Cel:** Wyświetla przystanki z wieloma pobliskimi połączeniami (węzły przesiadkowe).

<!-- Wklej tutaj diagram z draw.io: query8_diagram.drawio -->

---

### Query 9: Znajdź najdłuższe pojedyncze kursy

**Cel:** Wyświetla najdłuższe kursy według linii (liczba przystanków i czas trwania).

<!-- Wklej tutaj diagram z draw.io: query9_diagram.drawio -->

---

## Podsumowanie Wydajności

| Query | Opis | Czas wykonania |
|-------|------|----------------|
| Query 1 | Wyszukiwanie tras na przystanku | **141 ms** ⚡ |
| Query 2 | Rozkład odjazdów | **112 ms** ⚡ |
| Query 3 | Bezpośrednie połączenie | **463 ms** ⚡ |
| Query 4 | Połączenie z przesiadką | **22 s** ⏱️ |
| Query 5 | Wszystkie trasy z liczbą kursów | - |
| Query 6 | Najbardziej ruchliwe przystanki | - |
| Query 7 | Wzorzec częstotliwości | - |
| Query 8 | Węzły przesiadkowe | - |
| Query 9 | Najdłuższe kursy | - |

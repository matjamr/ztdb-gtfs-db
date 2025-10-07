#!/bin/bash

# ============================================================
# GTFS TO NEO4J - AUTOMATYCZNY IMPORT - WERSJA 2.0
# ============================================================
# Skrypt automatyzujący import danych GTFS do Neo4j
# Naprawiona wersja z optimizacjami dla dużych plików
# ============================================================

# Kolory dla outputu
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Konfiguracja Neo4j
NEO4J_USER="neo4j"
NEO4J_PASSWORD="VeryStrongPassword2137!"
NEO4J_HOST="localhost:7687"
NEO4J_DATABASE="neo4j"

# Ścieżka do plików GTFS (folder gdzie znajdują się pliki .txt)
GTFS_PATH="/import/gtfs"

# ============================================================
# FUNKCJE POMOCNICZE (bez zmian)
# ============================================================

print_header() {
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

execute_cypher() {
    local query="$1"
    local description="$2"

    echo -e "${YELLOW}Wykonuję: $description${NC}"

    echo "$query" | cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
        -a "$NEO4J_HOST" -d "$NEO4J_DATABASE" --format plain

    if [ $? -eq 0 ]; then
        print_success "$description - OK"
        return 0
    else
        print_error "$description - BŁĄD"
        return 1
    fi
}

check_file() {
    if [ ! -f "$1" ]; then
        print_error "Plik nie istnieje: $1"
        return 1
    fi
    print_success "Znaleziono plik: $1"
    return 0
}

# ============================================================
# SPRAWDZANIE WYMAGAŃ (bez zmian)
# ============================================================

print_header "SPRAWDZANIE WYMAGAŃ"

# Sprawdź cypher-shell
if ! command -v cypher-shell &> /dev/null; then
    print_error "cypher-shell nie jest zainstalowany!"
    echo "Zainstaluj Neo4j lub dodaj cypher-shell do PATH"
    exit 1
fi
print_success "cypher-shell znaleziony"

# Sprawdź połączenie z Neo4j
echo "RETURN 1 as test;" | cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
    -a "$NEO4J_HOST" -d "$NEO4J_DATABASE" --format plain &> /dev/null

if [ $? -ne 0 ]; then
    print_error "Nie można połączyć z Neo4j!"
    echo "Sprawdź:"
    echo "  - Czy Neo4j jest uruchomiony"
    echo "  - Poprawność użytkownika i hasła"
    echo "  - Adres hosta: $NEO4J_HOST"
    exit 1
fi
print_success "Połączenie z Neo4j OK"

# Sprawdź folder GTFS
if [ ! -d "$GTFS_PATH" ]; then
    print_error "Folder GTFS nie istnieje: $GTFS_PATH"
    exit 1
fi
print_success "Folder GTFS znaleziony: $GTFS_PATH"

# Sprawdź wymagane pliki
REQUIRED_FILES=("stops.txt" "routes.txt" "trips.txt" "stop_times.txt")
for file in "${REQUIRED_FILES[@]}"; do
    check_file "$GTFS_PATH/$file" || exit 1
done

# ============================================================
# KROK 0: CZYSZCZENIE BAZY (bez zmian)
# ============================================================

print_header "KROK 0: CZYSZCZENIE BAZY"
read -p "Czy chcesz wyczyścić bazę danych? (t/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Tt]$ ]]; then
    execute_cypher "MATCH (n) DETACH DELETE n;" "Czyszczenie bazy danych"
else
    print_info "Pominięto czyszczenie bazy"
fi

# ============================================================
# KROK 1: TWORZENIE OGRANICZEŃ I INDEKSÓW - ROZSZERZONE
# ============================================================

print_header "KROK 1: TWORZENIE OGRANICZEŃ I INDEKSÓW"

CONSTRAINTS=(
    "CREATE CONSTRAINT IF NOT EXISTS FOR (s:Stop) REQUIRE s.stop_id IS UNIQUE;"
    "CREATE CONSTRAINT IF NOT EXISTS FOR (r:Route) REQUIRE r.route_id IS UNIQUE;"
    "CREATE CONSTRAINT IF NOT EXISTS FOR (t:Trip) REQUIRE t.trip_id IS UNIQUE;"
)

for constraint in "${CONSTRAINTS[@]}"; do
    execute_cypher "$constraint" "Tworzenie constraint"
    sleep 1
done

# Dodatkowe indeksy dla lepszej wydajności
INDEXES=(
    "CREATE INDEX IF NOT EXISTS FOR (s:Stop) ON (s.stop_name);"
    "CREATE INDEX IF NOT EXISTS FOR (r:Route) ON (r.route_short_name);"
    "CREATE INDEX IF NOT EXISTS FOR (t:Trip) ON (t.service_id);"
    "CREATE INDEX IF NOT EXISTS FOR (t:Trip) ON (t.route_id);"
)

for index in "${INDEXES[@]}"; do
    execute_cypher "$index" "Tworzenie indeksu"
    sleep 1
done

# ============================================================
# KROK 2-4: IMPORT WĘZŁÓW (bez zmian)
# ============================================================

print_header "KROK 2: IMPORT PRZYSTANKÓW (stops.txt)"

STOPS_QUERY="
LOAD CSV WITH HEADERS FROM 'file:///stops.txt' AS row
CALL {
  WITH row
  CREATE (s:Stop {
      stop_id: row.stop_id,
      stop_code: row.stop_code,
      stop_name: row.stop_name,
      stop_desc: row.stop_desc,
      stop_lat: toFloat(row.stop_lat),
      stop_lon: toFloat(row.stop_lon),
      zone_id: row.zone_id,
      stop_url: row.stop_url,
      location_type: CASE WHEN row.location_type IS NOT NULL
                          THEN toInteger(row.location_type)
                          ELSE 0 END,
      parent_station: row.parent_station
  })
} IN TRANSACTIONS OF 1000 ROWS;
"

execute_cypher "$STOPS_QUERY" "Import przystanków"

print_header "KROK 3: IMPORT TRAS (routes.txt)"

ROUTES_QUERY="
LOAD CSV WITH HEADERS FROM 'file:///routes.txt' AS row
CALL {
  WITH row
  CREATE (r:Route {
      route_id: row.route_id,
      agency_id: row.agency_id,
      route_short_name: row.route_short_name,
      route_long_name: row.route_long_name,
      route_desc: row.route_desc,
      route_type: toInteger(row.route_type),
      route_url: row.route_url,
      route_color: row.route_color,
      route_text_color: row.route_text_color
  })
} IN TRANSACTIONS OF 1000 ROWS;
"

execute_cypher "$ROUTES_QUERY" "Import tras"

print_header "KROK 4: IMPORT PRZEJAZDÓW (trips.txt)"

TRIPS_QUERY="
LOAD CSV WITH HEADERS FROM 'file:///trips.txt' AS row
CALL {
  WITH row
  CREATE (t:Trip {
      trip_id: row.trip_id,
      route_id: row.route_id,
      service_id: row.service_id,
      trip_headsign: row.trip_headsign,
      trip_short_name: row.trip_short_name,
      direction_id: CASE WHEN row.direction_id IS NOT NULL
                         THEN toInteger(row.direction_id)
                         ELSE 0 END,
      block_id: row.block_id,
      shape_id: row.shape_id,
      wheelchair_accessible: CASE WHEN row.wheelchair_accessible IS NOT NULL
                                   THEN toInteger(row.wheelchair_accessible)
                                   ELSE 0 END,
      bikes_allowed: CASE WHEN row.bikes_allowed IS NOT NULL
                          THEN toInteger(row.bikes_allowed)
                          ELSE 0 END
  })
} IN TRANSACTIONS OF 1000 ROWS;
"

execute_cypher "$TRIPS_QUERY" "Import przejazdów"

# ============================================================
# KROK 5: ŁĄCZENIE TRIP Z ROUTE - ZOPTYMALIZOWANE
# ============================================================

print_header "KROK 5: ŁĄCZENIE PRZEJAZDÓW Z TRASAMI"

LINK_QUERY="
MATCH (t:Trip)
CALL {
  WITH t
  MATCH (r:Route {route_id: t.route_id})
  CREATE (t)-[:ON_ROUTE]->(r)
} IN TRANSACTIONS OF 10000 ROWS;
"

execute_cypher "$LINK_QUERY" "Łączenie Trip-Route"

# ============================================================
# KROK 6: IMPORT CZASÓW PRZYSTANKÓW - NOWA METODA
# ============================================================

print_header "KROK 6: IMPORT CZASÓW PRZYSTANKÓW (stop_times.txt)"
print_info "To może zająć 10-30 minut dla dużych zbiorów danych..."
print_info "Używam zoptymalizowanej metody batchowej..."

# Metoda 1: Batch ze zmniejszonymi transakcjami
STOP_TIMES_QUERY="
LOAD CSV WITH HEADERS FROM 'file:///stop_times.txt' AS row
CALL {
  WITH row
  MATCH (t:Trip {trip_id: row.trip_id})
  MATCH (s:Stop {stop_id: row.stop_id})
  CREATE (t)-[:STOPS_AT {
      arrival_time: row.arrival_time,
      departure_time: row.departure_time,
      stop_sequence: toInteger(row.stop_sequence),
      stop_headsign: row.stop_headsign,
      pickup_type: CASE WHEN row.pickup_type IS NOT NULL
                        THEN toInteger(row.pickup_type)
                        ELSE 0 END,
      drop_off_type: CASE WHEN row.drop_off_type IS NOT NULL
                          THEN toInteger(row.drop_off_type)
                          ELSE 0 END
  }]->(s)
} IN TRANSACTIONS OF 500 ROWS;
"

execute_cypher "$STOP_TIMES_QUERY" "Import stop_times (batch method)"

# ============================================================
# KROK 7: TWORZENIE POŁĄCZEŃ NEXT_STOP - ZOPTYMALIZOWANE
# ============================================================

print_header "KROK 7: TWORZENIE POŁĄCZEŃ MIĘDZY PRZYSTANKAMI"
print_info "Tworzenie relacji NEXT_STOP w batch..."

NEXT_STOP_QUERY="
MATCH (t:Trip)
CALL {
  WITH t
  MATCH (t)-[r1:STOPS_AT]->(s1:Stop)
  MATCH (t)-[r2:STOPS_AT]->(s2:Stop)
  WHERE r2.stop_sequence = r1.stop_sequence + 1
  WITH t, s1, s2, r1, r2
  MATCH (t)-[:ON_ROUTE]->(route:Route)
  CREATE (s1)-[:NEXT_STOP {
      trip_id: t.trip_id,
      route_id: route.route_id,
      service_id: t.service_id,
      departure_time: r1.departure_time,
      arrival_time: r2.arrival_time,
      from_sequence: r1.stop_sequence,
      to_sequence: r2.stop_sequence
  }]->(s2)
} IN TRANSACTIONS OF 100 ROWS;
"

execute_cypher "$NEXT_STOP_QUERY" "Tworzenie NEXT_STOP"

# ============================================================
# RESZTA SKRYPTU (bez zmian) - KALENDARZ I AGENCJE
# ============================================================

if [ -f "$GTFS_PATH/calendar.txt" ]; then
    print_header "KROK 8: IMPORT KALENDARZA (calendar.txt)"

    CALENDAR_QUERY="
    LOAD CSV WITH HEADERS FROM 'file:///calendar.txt' AS row
    CALL {
      WITH row
      CREATE (c:Calendar {
          service_id: row.service_id,
          monday: toInteger(row.monday),
          tuesday: toInteger(row.tuesday),
          wednesday: toInteger(row.wednesday),
          thursday: toInteger(row.thursday),
          friday: toInteger(row.friday),
          saturday: toInteger(row.saturday),
          sunday: toInteger(row.sunday),
          start_date: row.start_date,
          end_date: row.end_date
      })
    } IN TRANSACTIONS OF 1000 ROWS;
    "

    execute_cypher "$CALENDAR_QUERY" "Import kalendarza"

    LINK_CALENDAR_QUERY="
    MATCH (t:Trip)
    CALL {
      WITH t
      MATCH (c:Calendar {service_id: t.service_id})
      CREATE (t)-[:OPERATES_ON]->(c)
    } IN TRANSACTIONS OF 10000 ROWS;
    "

    execute_cypher "$LINK_CALENDAR_QUERY" "Łączenie Trip-Calendar"
else
    print_info "Plik calendar.txt nie istnieje - pomijam"
fi

if [ -f "$GTFS_PATH/agency.txt" ]; then
    print_header "KROK 9: IMPORT AGENCJI (agency.txt)"

    AGENCY_QUERY="
    LOAD CSV WITH HEADERS FROM 'file:///agency.txt' AS row
    CALL {
      WITH row
      CREATE (a:Agency {
          agency_id: row.agency_id,
          agency_name: row.agency_name,
          agency_url: row.agency_url,
          agency_timezone: row.agency_timezone,
          agency_lang: row.agency_lang,
          agency_phone: row.agency_phone
      })
    } IN TRANSACTIONS OF 1000 ROWS;
    "

    execute_cypher "$AGENCY_QUERY" "Import agencji"

    LINK_AGENCY_QUERY="
    MATCH (r:Route)
    CALL {
      WITH r
      MATCH (a:Agency {agency_id: r.agency_id})
      CREATE (r)-[:OPERATED_BY]->(a)
    } IN TRANSACTIONS OF 10000 ROWS;
    "

    execute_cypher "$LINK_AGENCY_QUERY" "Łączenie Route-Agency"
else
    print_info "Plik agency.txt nie istnieje - pomijam"
fi

# ============================================================
# STATYSTYKI KOŃCOWE
# ============================================================

print_header "STATYSTYKI IMPORTU"

STATS_QUERY="
MATCH (s:Stop) WITH count(s) as stops
MATCH (r:Route) WITH stops, count(r) as routes
MATCH (t:Trip) WITH stops, routes, count(t) as trips
MATCH (:Trip)-[st:STOPS_AT]->(:Stop) WITH stops, routes, trips, count(st) as stop_times
MATCH (:Stop)-[ns:NEXT_STOP]->(:Stop) WITH stops, routes, trips, stop_times, count(ns) as connections
RETURN
    stops,
    routes,
    trips,
    stop_times,
    connections;
"

execute_cypher "$STATS_QUERY" "Pobieranie statystyk"

print_header "IMPORT ZAKOŃCZONY POMYŚLNIE!"
print_success "Dane GTFS zostały zaimportowane do Neo4j"

# ============================================================
# WERYFIKACJA CZY SĄ DANE
# ============================================================

print_header "WERYFIKACJA DANYCH"

execute_cypher "MATCH (n) RETURN labels(n) as label, count(n) as count ORDER BY label;" "Lista wszystkich typów węzłów"
execute_cypher "MATCH ()-[r]->() RETURN type(r) as relationship, count(r) as count ORDER BY relationship;" "Lista wszystkich typów relacji"
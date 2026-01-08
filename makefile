URL=https://kolejemalopolskie.com.pl/rozklady_jazdy/ald-gtfs.zip
FILE=gtfs.zip

# Bootstrap entire environment
bootstrap: up load-postgres clean

# Start all containers
up:
	@echo "Starting containers..."
	docker-compose up -d
	@echo "Waiting 15 seconds for services to initialize..."
	@sleep 15
	@echo "Containers started successfully"

# Load GTFS data into PostgreSQL
load-postgres:
	@echo "================================================"
	@echo "Loading GTFS data into PostgreSQL"
	@echo "================================================"

	@echo "1. Extracting GTFS zip file..."
	unzip -o gtfs.zip -d gtfs

	@echo "2. Copying GTFS files to PostgreSQL container..."
	@CID=$$(docker-compose ps -q postgres); \
	docker exec $$CID mkdir -p /import/gtfs; \
	docker cp gtfs/. $$CID:/import/gtfs/

	@echo "3. Loading GTFS data into PostgreSQL..."
	@CID=$$(docker-compose ps -q postgres); \
	docker exec $$CID psql -U postgres -d mydb -f /docker-entrypoint-initdb.d/load_gtfs.sql

	@echo "4. GTFS data loaded successfully!"
	@echo "================================================"

# Load GTFS data into Neo4j (original)
load-neo4j:
	@echo "================================================"
	@echo "Loading GTFS data into Neo4j"
	@echo "================================================"

	@echo "1. Extracting GTFS zip file..."
	unzip -o gtfs.zip -d gtfs

	@echo "2. Copying GTFS files to Neo4j container..."
	@CID=$$(docker-compose ps -q neo4j); \
	docker cp gtfs $$CID:/import

	@echo "3. Neo4j data copied. Load via Java application."
	@echo "================================================"

# Clean temporary files
clean:
	@echo "Cleaning up temporary files..."
	rm -rf gtfs
	@echo "Cleanup complete"

# Stop all containers
down:
	@echo "Stopping all containers..."
	docker-compose down
	@echo "Containers stopped"

# Stop and remove volumes (full reset)
reset:
	@echo "WARNING: This will delete all data!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down -v; \
		echo "All containers and volumes removed"; \
	else \
		echo "Reset cancelled"; \
	fi

# Show logs for all services
logs:
	docker-compose logs -f

# Show PostgreSQL logs
logs-postgres:
	docker-compose logs -f postgres

# Show Neo4j logs
logs-neo4j:
	docker-compose logs -f neo4j

# Connect to PostgreSQL CLI
psql:
	@CID=$$(docker-compose ps -q postgres); \
	docker exec -it $$CID psql -U postgres -d mydb

# Connect to Neo4j Cypher Shell
cypher:
	@CID=$$(docker-compose ps -q neo4j); \
	docker exec -it $$CID cypher-shell -u neo4j -p VeryStrongPassword2137!

# Check service status
status:
	docker-compose ps

# Test PostgreSQL queries
test-postgres:
	@echo "Testing PostgreSQL connection and sample query..."
	@CID=$$(docker-compose ps -q postgres); \
	docker exec $$CID psql -U postgres -d mydb -c "SELECT 'agency' as table_name, COUNT(*) as row_count FROM agency UNION ALL SELECT 'routes', COUNT(*) FROM routes UNION ALL SELECT 'stops', COUNT(*) FROM stops UNION ALL SELECT 'trips', COUNT(*) FROM trips UNION ALL SELECT 'stop_times', COUNT(*) FROM stop_times;"

# Download latest GTFS data
download:
	@echo "Downloading latest GTFS data..."
	wget -O gtfs.zip $(URL)
	@echo "Download complete"

# Full refresh: download, reset, and reload
refresh: download reset up load-postgres clean

.PHONY: bootstrap up load-postgres load-neo4j clean down reset logs logs-postgres logs-neo4j psql cypher status test-postgres download refresh
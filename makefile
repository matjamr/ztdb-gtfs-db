URL=https://kolejemalopolskie.com.pl/rozklady_jazdy/ald-gtfs.zip
FILE=gtfs.zip

all: download up load

download:
	wget -O $(FILE) $(URL)

up:
	@echo "Starting Neo4j container..."
	-docker-compose up -d
	@echo "Czekam 10 sekund..."
	@sleep 10
	@CID=$$(docker-compose ps -q neo4j); \
	echo "Kontener: $$CID"; \
	echo "Przeglądam logi:"; \
	docker logs $$CID | head -n 20

load:
	@echo "Starting loading data to db"
	unzip -o gtfs.zip -d gtfs
	docker cp deployment/neo4j/import_gtfs.cypher $$CID:/import/gtfs/import_gtfs.cypher
	@CID=$$(docker-compose ps -q neo4j); \
	docker cp $(FILE) $$CID:/import/$(FILE); \
	docker exec $$CID sh -c "unzip -o /import/$(FILE) -d /import/gtfs"; \
	docker exec $$CID cypher-shell -u neo4j -p VeryStrongPassword2137! -f /import/gtfs/import_gtfs.cypher

clean:
	rm -f $(FILE)

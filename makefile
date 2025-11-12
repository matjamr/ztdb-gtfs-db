URL=https://kolejemalopolskie.com.pl/rozklady_jazdy/ald-gtfs.zip
FILE=gtfs.zip

bootstrap: up load clean

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
	@echo "Rozpoczecie ladowania danych do bazy"
	unzip -o gtfs.zip -d gtfs

	@CID=$$(docker-compose ps -q neo4j); \
	docker cp gtfs $$CID:/import

	@echo "Zaladowane dane do bazy."

clean:
	@echo "Usuwanie niepotrzebnych danych"
	rm -rf gtfs

down:
	docker-compose down
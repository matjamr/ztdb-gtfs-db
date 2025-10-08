URL=https://kolejemalopolskie.com.pl/rozklady_jazdy/ald-gtfs.zip
FILE=gtfs.zip

bootstrap: download up load clean

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
	@echo "Rozpoczecie ladowania danych do bazy"
	unzip -o gtfs.zip -d gtfs

	@CID=$$(docker-compose ps -q neo4j); \
	docker cp gtfs $$CID:/import

	@CID=$$(docker-compose ps -q neo4j); \
	docker cp deployment/neo4j/import.sh $$CID:/import/gtfs

	@CID=$$(docker-compose ps -q neo4j); \
	docker exec $$CID chmod 777 /import/gtfs/import.sh

	@CID=$$(docker-compose ps -q neo4j); \
	printf 'bash /import/gtfs/import.sh\n' | docker exec -i $$CID bash -s
	@echo "Zaladowane dane do bazy."

clean:
	@echo "Usuwanie niepotrzebnych danych"
	rm -f gtfs.zip

down:
	docker-compose down
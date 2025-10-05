up:
	docker-compose up -d

down:
	docker-compose down

prune:
	docker system prune -f

start: up

stop: down

reload: down up

feed-data:
	docker-compose exec app ./feed_data.sh

logs:
	docker-compose logs -f
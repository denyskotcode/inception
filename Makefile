COMPOSE_FILE = srcs/docker-compose.yml

all: setup up

setup:
	@mkdir -p /home/dkot/data/mariadb
	@mkdir -p /home/dkot/data/wordpress
	@echo "Data directories created."

up:
	docker compose -f $(COMPOSE_FILE) up -d --build

down:
	docker compose -f $(COMPOSE_FILE) down

logs:
	docker compose -f $(COMPOSE_FILE) logs -f

ps:
	docker compose -f $(COMPOSE_FILE) ps

re: down up

clean:
	docker compose -f $(COMPOSE_FILE) down --rmi all -v
	sudo rm -rf /home/dkot/data/mariadb/*
	sudo rm -rf /home/dkot/data/wordpress/*
	@echo "All containers, images, volumes and data removed."

.PHONY: all setup up down logs ps re clean
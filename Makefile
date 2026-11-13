.DEFAULT_GOAL := help
.PHONY: help setup db db-down backend frontend dev

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-10s %s\n", $$1, $$2}'

setup: ## Init submodules, install deps, build backend dist
	git submodule update --init
	cd Bomberman-2.0-Backend && HUSKY=0 npm ci
	cd Bomberman-2.0-Backend && npm run build
	cd Bomberman-2.0 && HUSKY=0 npm ci

db: ## Start local MongoDB (docker) and wait until healthy
	docker compose up -d --wait mongo

db-down: ## Stop local MongoDB
	docker compose down

backend: ## Run backend on :4000 against local MongoDB (never production)
	cd Bomberman-2.0-Backend && DB_HOST=mongodb://localhost:27017/bomberman CLOUDINARY_CLOUD_NAME= CLOUDINARY_API_KEY= CLOUDINARY_API_SECRET= npm run dev

frontend: ## Run frontend on :3000 against local backend
	cd Bomberman-2.0 && VITE_SERVER_BASE_URL=http://localhost:4000 npm run dev

dev: db ## Start MongoDB, backend and frontend
	$(MAKE) -j2 backend frontend

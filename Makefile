.DEFAULT_GOAL := help
.PHONY: help setup db db-down backend frontend dev browsers browsers-down

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'

setup: ## Init submodules, install deps, build backend dist
	git submodule update --init
	cd Bomberman-2.0-Backend && HUSKY=0 npm ci
	cd Bomberman-2.0-Backend && npm run build
	cd Bomberman-2.0 && HUSKY=0 npm ci

db: ## Start local MongoDB (docker) and wait until healthy
	docker compose up -d --wait mongo

db-down: ## Stop local MongoDB
	docker compose down

# The backend resolves its @aliases (module-alias) from ./dist, so `npm run dev` (ts-node)
# would run stale dist code. Rebuild dist and restart on every src change instead.
backend: ## Run backend on :4000 against local MongoDB (never production); rebuilds dist on src change
	cd Bomberman-2.0-Backend && DB_HOST=mongodb://localhost:27017/bomberman CLOUDINARY_CLOUD_NAME= CLOUDINARY_API_KEY= CLOUDINARY_API_SECRET= npx nodemon --watch src --ext ts,json --exec 'npm run build && node dist/app.js'

frontend: ## Run frontend on :3000 against local backend
	cd Bomberman-2.0 && VITE_SERVER_BASE_URL=http://localhost:4000 npm run dev

dev: db ## Start MongoDB, backend and frontend
	$(MAKE) -j2 backend frontend

# Two normal Chrome windows with separate profiles for the play-local skill.
# Debug ports listen on 127.0.0.1 only. `open` starts the app with cwd /, so paths are absolute.
browsers: ## Start two Chrome windows (debug ports 9223, 9224) for play-local
	@mkdir -p "$(CURDIR)/local/browser-profiles/player1" "$(CURDIR)/local/browser-profiles/player2"
	@for pair in 9223:player1 9224:player2; do \
		port=$${pair%%:*}; name=$${pair##*:}; \
		if curl -s http://127.0.0.1:$$port/json/version >/dev/null 2>&1; then \
			echo "$$name: port $$port already in use, skipped"; \
		else \
			open -na "Google Chrome" --args --remote-debugging-port=$$port --user-data-dir="$(CURDIR)/local/browser-profiles/$$name" --no-first-run --no-default-browser-check http://localhost:3000; \
			echo "$$name: started on port $$port"; \
		fi; \
	done

browsers-down: ## Close only the two play-local Chrome windows
	@for name in player1 player2; do \
		pkill -f -- "--user-data-dir=$(CURDIR)/local/browser-profiles/$$name( |$$)" && echo "$$name: closed" || echo "$$name: not running"; \
	done

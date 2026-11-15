.DEFAULT_GOAL := help
.PHONY: help setup db db-down backend frontend dev ci e2e browsers browsers-down browsers-reset

help: ## Show this help
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'

setup: ## Init submodules, install deps, build backend dist
	git submodule update --init
	cd Bomberman-2.0-Backend && HUSKY=0 npm ci
	cd Bomberman-2.0-Backend && npm run build
	cd Bomberman-2.0 && HUSKY=0 npm ci
	cd Bomberman-2.0-E2E && npm ci && npx playwright install chromium

db: ## Start local MongoDB (docker) and wait until healthy
	docker compose up -d --wait mongo

db-down: ## Stop local MongoDB
	docker compose down

# The backend resolves its @aliases (module-alias) from ./dist, so rebuild dist and
# restart on every src change.
backend: ## Run backend on :4000 against local MongoDB (never production); rebuilds dist on src change
	cd Bomberman-2.0-Backend && DB_HOST=mongodb://localhost:27017/bomberman CLOUDINARY_CLOUD_NAME= CLOUDINARY_API_KEY= CLOUDINARY_API_SECRET= npx nodemon --watch src --ext ts,json --exec 'npm run build && node dist/app.js'

frontend: ## Run frontend on :3000 against local backend
	cd Bomberman-2.0 && VITE_SERVER_BASE_URL=http://localhost:4000 npm run dev

dev: db ## Start MongoDB, backend and frontend
	$(MAKE) -j2 backend frontend

# The same steps as the `checks` CI job (.github/workflows/ci.yml) in each child repo,
# run on the current checkout of each repo. Keep in sync with ci.yml.
ci: ## Run every CI step in all repos (required before opening a PR)
	cd Bomberman-2.0-Backend && npm run check && npm run typecheck && npm test && npm run build
	cd Bomberman-2.0 && npm run check && npm run typecheck && VITE_CLIENT_ID=ci-placeholder VITE_SERVER_BASE_URL=http://localhost:4000 npm run build
	cd Bomberman-2.0-E2E && npm run check && npm run typecheck
	@echo "ci: all steps passed in all repos"

# The E2E suite against a fresh local stack built from the current checkouts.
# Needs :3000 and :4000 free (stop make dev). Always stops the stack.
e2e: db ## Run the E2E suite against a fresh local stack (stop make dev first)
	cd Bomberman-2.0-E2E && npm run stack:up && { npx playwright test; status=$$?; npm run stack:down; exit $$status; }

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
	@for pair in 9223:player1 9224:player2; do \
		port=$${pair%%:*}; name=$${pair##*:}; ok=; \
		for i in $$(seq 1 30); do \
			if curl -s http://127.0.0.1:$$port/json/version >/dev/null 2>&1; then ok=1; break; fi; \
			sleep 0.5; \
		done; \
		if [ -z "$$ok" ]; then \
			echo "$$name: port $$port did not answer after 15 s. Chrome may already run with this profile without the debug port. Run 'make browsers-down' first, then retry." >&2; \
			exit 1; \
		fi; \
	done

browsers-down: ## Close only the two play-local Chrome windows
	@for name in player1 player2; do \
		pkill -f -- "--user-data-dir=$(CURDIR)/local/browser-profiles/$$name( |$$)" && echo "$$name: closed" || echo "$$name: not running"; \
	done

browsers-reset: browsers-down ## Close the windows and delete the two play-local profiles
	@rm -rf "$(CURDIR)/local/browser-profiles/player1" "$(CURDIR)/local/browser-profiles/player2"
	@echo "play-local profiles deleted"

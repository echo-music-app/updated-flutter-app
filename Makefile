CURRENT_USER := $(shell id -u):$(shell id -g)
DOCKER_COMPOSE := CURRENT_USER=$(CURRENT_USER) docker compose

.PHONY: up up-once down logs dev build-dev install test lint format check migrate mobile-icons hooks-install

up: down
	$(DOCKER_COMPOSE) up -d --build

up-once:
	@if [ -n "$$($(DOCKER_COMPOSE) ps -q backend-dev)" ]; then \
		echo "backend-dev is already running; skipping compose up"; \
	else \
		$(DOCKER_COMPOSE) up -d --build; \
	fi

down:
	$(DOCKER_COMPOSE) down --remove-orphans

cli:
	$(DOCKER_COMPOSE) exec backend-dev bash

garage-cli:
	$(DOCKER_COMPOSE) exec storage /garage $(args)

garage-init:
	@node_id=$$($(DOCKER_COMPOSE) exec storage /garage status | awk '/^[0-9a-f]{16}[[:space:]]/{print $$1; exit}'); \
	test -n "$$node_id" || { echo "Could not determine Garage node ID from status output"; exit 1; }; \
	$(DOCKER_COMPOSE) exec storage /garage layout assign -z dc1 -c 1G "$$node_id"
	$(DOCKER_COMPOSE) exec storage /garage layout apply --version 1
	$(DOCKER_COMPOSE) exec storage /garage bucket create profile-images
	$(DOCKER_COMPOSE) exec storage /garage bucket create user-contents-public
	$(DOCKER_COMPOSE) exec storage /garage bucket create user-contents-private

logs:
	$(DOCKER_COMPOSE) logs -f

dev:
	cd backend && uv run uvicorn backend.main:app --reload --port 8000

dev-admin:
	cd backend && uv run uvicorn backend.admin:admin_app --reload --port 8001

lint:
	$(DOCKER_COMPOSE) exec -T backend-dev ruff check src tests

ruff-fix:
	$(DOCKER_COMPOSE) exec -T backend-dev ruff check --fix src tests

format:
	$(DOCKER_COMPOSE) exec -T backend-dev sh -c "black src tests && isort src tests"

check:
	$(DOCKER_COMPOSE) exec -T backend-dev sh -c "black --check src tests && isort --check-only src tests"

test:
	$(DOCKER_COMPOSE) exec -T backend-dev pytest --cov --cov-report=term-missing $(test-args)

test-no-coverage:
	$(DOCKER_COMPOSE) exec -T backend-dev pytest $(test-args)

install:
	cd backend && uv sync --locked --dev

migrate:
	$(DOCKER_COMPOSE) exec -T backend-dev alembic upgrade head

# Generate all app icons and favicons from a source image.
# Usage: make mobile-icons SRC=path/to/image.png
SRC ?= mobile/assets/images/logo_dark.png
mobile-icons:
	@command -v convert >/dev/null 2>&1 || { echo "ImageMagick is required (brew install imagemagick / apt install imagemagick)"; exit 1; }
	@test -f "$(SRC)" || { echo "Source image not found: $(SRC)  (override with SRC=path/to/image.png)"; exit 1; }
	@echo "Generating icons from $(SRC)..."
	@# --- Android mipmap ---
	convert "$(SRC)" -resize 48x48   mobile/android/app/src/main/res/mipmap-mdpi/ic_launcher.png
	convert "$(SRC)" -resize 72x72   mobile/android/app/src/main/res/mipmap-hdpi/ic_launcher.png
	convert "$(SRC)" -resize 96x96   mobile/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
	convert "$(SRC)" -resize 144x144 mobile/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
	convert "$(SRC)" -resize 192x192 mobile/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
	@# --- iOS AppIcon ---
	convert "$(SRC)" -resize 20x20   mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png
	convert "$(SRC)" -resize 40x40   mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png
	convert "$(SRC)" -resize 60x60   mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png
	convert "$(SRC)" -resize 29x29   mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png
	convert "$(SRC)" -resize 58x58   mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png
	convert "$(SRC)" -resize 87x87   mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png
	convert "$(SRC)" -resize 40x40   mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png
	convert "$(SRC)" -resize 80x80   mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png
	convert "$(SRC)" -resize 120x120 mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png
	convert "$(SRC)" -resize 120x120 mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png
	convert "$(SRC)" -resize 180x180 mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png
	convert "$(SRC)" -resize 76x76   mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png
	convert "$(SRC)" -resize 152x152 mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png
	convert "$(SRC)" -resize 167x167 mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png
	convert "$(SRC)" -resize 1024x1024 mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
	@# --- Web PWA icons ---
	convert "$(SRC)" -resize 192x192 mobile/web/icons/Icon-192.png
	convert "$(SRC)" -resize 512x512 mobile/web/icons/Icon-512.png
	convert "$(SRC)" -resize 192x192 mobile/web/icons/Icon-maskable-192.png
	convert "$(SRC)" -resize 512x512 mobile/web/icons/Icon-maskable-512.png
	@# --- Web favicon ---
	convert "$(SRC)" -resize 16x16   mobile/web/favicon.png
	@echo "Done."

serena-index:
	uvx --from git+https://github.com/oraios/serena serena project index

hooks-install:
	git config core.hooksPath .githooks
	chmod +x .githooks/pre-push

seed-db:
	$(DOCKER_COMPOSE) exec -T postgres psql -U echo -d echo < shared/test_data.sql

ENDPOINT ?= http://localhost:4566
export AWS_ENDPOINT_URL=$(ENDPOINT)
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

.PHONY: up down smoke lambda test all clean
up:      ## start MiniStack
	docker compose up -d
down:    ## stop MiniStack and wipe state
	docker compose down -v
smoke:   ## fast plumbing smoke tests
	pytest -m smoke -q
lambda:  ## lambda execution smoke (needs Docker)
	pytest -m lambda_exec -q
test:    ## run all smoke tests (plumbing + lambda exec)
	pytest -q
all: smoke lambda
clean:   ## stop MiniStack and remove local test artifacts
	docker compose down -v || true
	rm -rf .pytest_cache __pycache__ tests/__pycache__

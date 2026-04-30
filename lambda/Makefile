.PHONY: build validate deploy delete clean help

STAGE ?= dev

##--------------------------------------------------------------
## Build
##--------------------------------------------------------------
build: ## Build Go Lambda functions
	../scripts/go/build.sh cmd lambda arm64

##--------------------------------------------------------------
## SAM
##--------------------------------------------------------------
validate: build ## Validate SAM template
	sam validate --lint

deploy: build ## Deploy stack (STAGE=dev|stg|prd)
	sam deploy --config-env $(STAGE)

delete: ## Delete stack (STAGE=dev|stg|prd)
	sam delete --config-env $(STAGE)

local-invoke: build ## Invoke function locally (FUNCTION=xxx STAGE=dev)
	sam local invoke $(FUNCTION) --config-env $(STAGE)

##--------------------------------------------------------------
## Misc
##--------------------------------------------------------------
clean: ## Remove build artifacts
	rm -rf ./bin ./outputs ./coverage

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

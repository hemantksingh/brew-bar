.PHONY: build run test loadtest stack destroy-stack output

APP?=orders

build:
	cd $(APP) && \
	npm install && \
	npm run build

run:
	node js/app.js

test:
	cd $(APP) && npm install && npm test

loadtest:
	cd tests/loadtests && \
	pipenv run locust

REGION?=eu-west-2
STACK_PREFIX?=brewbar
TF_DIR=provisioning
TF_PLAN=$(STACK_PREFIX).$@.tfplan

define tfinit
	terraform -chdir=$(TF_DIR) init
endef

stack:
	$(call tfinit,$@) && \
	terraform -chdir=$(TF_DIR) plan \
		-var stack_prefix=$(STACK_PREFIX) \
		-var region=$(REGION) \
		-var permissions_boundary_policy=$(PERMISSIONS_BOUNDARY_POLICY) \
		-out $(TF_PLAN)
ifeq ($(APPLY), true)
	terraform -chdir=$(TF_DIR) apply $(TF_PLAN)
else
	@echo Skipping apply ...
endif

destroy-stack:
	terraform -chdir=$(TF_DIR) destroy \
		-var stack_prefix=$(STACK_PREFIX) \
		-var region=$(REGION) \
		-var permissions_boundary_policy=$(PERMISSIONS_BOUNDARY_POLICY)

output:
	terraform -chdir=$(TF_DIR) output
.PHONY: build run test loadtest stack destroy-stack

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

REGION?=eu-west-1
STACK_PREFIX?=brewbar
TERRAFORM_DIR=provisioning


define tfinit
	cd $(TERRAFORM_DIR) && terraform init
endef

stack:
	$(call tfinit,$@) && \
	terraform plan \
		-var stack_prefix=$(STACK_PREFIX) \
		-var region=$(REGION) \
		-var permissions_boundary_policy=$(PERMISSIONS_BOUNDARY_POLICY) \
		-out $@.tfplan
ifeq ($(APPLY), true)
	cd $(TERRAFORM_DIR) && \
	terraform apply $@.tfplan
else
	@echo Skipping apply ...
endif

destroy-stack:
	cd $(TERRAFORM_DIR) && \
	terraform destroy \
		-var stack_prefix=$(STACK_PREFIX) \
		-var region=$(REGION) \
		-var permissions_boundary_policy=$(PERMISSIONS_BOUNDARY_POLICY)
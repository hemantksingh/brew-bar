.PHONY: build run test stack destroy-stack

build:
	npm install
	./node_modules/typescript/bin/tsc

run:
	node js/app.js

REGION?=eu-west-1
STACK_PREFIX?=hk-playground
TERRAFORM_DIR=provisioning

test:
	cd orders && AWS_REGION=$(REGION) npm test

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
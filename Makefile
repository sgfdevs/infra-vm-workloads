.PHONY: help tf-init tf-plan tf-show tf-output tf-apply tf-validate tf-format tf-lint-fix tf-providers-lock \
        ansible ansible-shell ansible-install ansible-inventory ansible-lint ansible-lint-fix

TF_DIR := src/tf
ANSIBLE_DIR := src/ansible
ENVRC := $(CURDIR)/.envrc
SHELL := bash

help:
	@echo "OpenTofu commands:"
	@echo "  Init:              make tf-init [ARGS='-backend=false']"
	@echo "  Plan:              make tf-plan [ARGS='-out=tfplan -destroy']"
	@echo "  Show:              make tf-show ARGS=<planfile>"
	@echo "  Output:            make tf-output [ARGS='-json']"
	@echo "  Apply:             make tf-apply [ARGS='-auto-approve tfplan']"
	@echo "  Validate:          make tf-validate"
	@echo "  Format check:      make tf-format"
	@echo "  Format fix:        make tf-lint-fix"
	@echo "  Providers lock:    make tf-providers-lock"
	@echo ""
	@echo "Ansible commands:"
	@echo "  Install deps:      make ansible-install"
	@echo "  Run playbook:      make ansible PLAYBOOK=playbook.yml [ARGS='-v']"
	@echo "  Inventory:         make ansible-inventory [ARGS='--list']"
	@echo "  Shell command:     make ansible-shell HOST=host COMMAND='cmd' [ARGS='-v']"
	@echo "  Lint:              make ansible-lint"
	@echo "  Lint fix:          make ansible-lint-fix"

tf-init:
	@source "$(ENVRC)" && tofu -chdir=$(TF_DIR) init $(ARGS)

tf-plan:
	@source "$(ENVRC)" && tofu -chdir=$(TF_DIR) plan $(ARGS)

tf-show:
	@source "$(ENVRC)" && tofu -chdir=$(TF_DIR) show $(ARGS)

tf-output:
	@source "$(ENVRC)" && tofu -chdir=$(TF_DIR) output $(ARGS)

tf-apply:
	@source "$(ENVRC)" && tofu -chdir=$(TF_DIR) apply $(ARGS)

tf-validate:
	@source "$(ENVRC)" && tofu -chdir=$(TF_DIR) validate

tf-format:
	@tofu -chdir=$(TF_DIR) fmt -check -recursive

tf-lint-fix:
	@tofu -chdir=$(TF_DIR) fmt -recursive

tf-providers-lock:
	@source "$(ENVRC)" && cd $(TF_DIR) && tofu providers lock \
		-platform=darwin_amd64 \
		-platform=darwin_arm64 \
		-platform=linux_amd64 \
		-platform=linux_arm64 \
		-platform=windows_amd64 \
		-platform=windows_arm64

ansible:
	@[ -n "$(PLAYBOOK)" ] || (echo "Error: PLAYBOOK required" && exit 1)
	@source "$(ENVRC)" && cd $(ANSIBLE_DIR) && uv run ansible-playbook playbooks/$(PLAYBOOK) $(ARGS)

ansible-shell:
	@[ -n "$(HOST)" ] || (echo "Error: HOST required (e.g., sgfdevs-k3s-01)" && exit 1)
	@[ -n "$(COMMAND)" ] || (echo "Error: COMMAND required (e.g., 'uname -a')" && exit 1)
	@source "$(ENVRC)" && cd $(ANSIBLE_DIR) && uv run ansible $(HOST) -m shell -a "$(COMMAND)" $(ARGS)

ansible-inventory:
	@source "$(ENVRC)" && cd $(ANSIBLE_DIR) && uv run ansible-inventory $(ARGS)

ansible-install:
	@cd $(ANSIBLE_DIR) && uv sync --locked && uv run ansible-galaxy collection install -r requirements.yml

ansible-lint:
	@cd $(ANSIBLE_DIR) && uv run ansible-lint

ansible-lint-fix:
	@cd $(ANSIBLE_DIR) && uv run ansible-lint --fix

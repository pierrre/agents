.PHONY: config
config:
	ln -sfn $(CURDIR) ~/.agents
	mkdir -p ~/.config
	ln -sfn $(CURDIR)/opencode ~/.config/opencode

.PHONY: update-skills
update-skills:
	git submodule update --init --remote skills/

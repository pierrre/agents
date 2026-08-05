.PHONY: config
config:
	ln -sfn $(CURDIR) ~/.agents
	mkdir -p ~/.config
	ln -sfn $(CURDIR)/opencode ~/.config/opencode

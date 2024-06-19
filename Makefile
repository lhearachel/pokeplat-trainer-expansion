GREEN := \x1b[1;31m
GREEN := \x1b[1;32m
RESET := \x1b[0;m

BASEDIR := base
BASEROM := pokeplatinum.us.nds

include tools.mk

$(BASEDIR):
	mkdir -p $(BASEDIR)

unpack-rom: $(NDSTOOL) | $(BASEDIR)
ifneq ("$(wildcard $(BASEROM))", "")
	@echo -e "$(GREEN)Unpacking $(BASEROM)...$(RESET)"
	@$(NDSTOOL) -x $(BASEROM) -9 $(BASEDIR)/arm9.bin
else
	@echo -e "$(RED)$(BASEROM) not found; cannot unpack$(RESET)"
endif


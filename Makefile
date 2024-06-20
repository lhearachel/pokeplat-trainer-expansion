GREEN := \x1b[1;31m
GREEN := \x1b[1;32m
RESET := \x1b[0;m

BASEDIR := base
BASEROM := pokeplatinum.us.nds
BUILDROM := pokeplatinum.us.patched.nds
FILESYS := filesys

NDSTOOL_ARGS := -9 $(BASEDIR)/arm9.bin -7 $(BASEDIR)/arm7.bin -y9 $(BASEDIR)/y9.bin -y7 $(BASEDIR)/y7.bin -d $(FILESYS) -y $(BASEDIR)/overlay -t $(BASEDIR)/banner.bin -h $(BASEDIR)/header.bin

SOURCES := $(wildcard *.s)

all: it

include tools.mk

$(BASEDIR):
	@mkdir -p $(BASEDIR)

$(FILESYS):
	@mkdir -p $(FILESYS)

unpack-rom: $(NDSTOOL) | $(BASEDIR) $(FILESYS)
ifneq ("$(wildcard $(BASEROM))", "")
	@echo -e "$(GREEN)Unpacking $(BASEROM)...$(RESET)"
	@$(NDSTOOL) -x $(BASEROM) $(NDSTOOL_ARGS)
else
	@echo -e "$(RED)$(BASEROM) not found; cannot unpack$(RESET)"
endif

it: unpack-rom $(SOURCES) | $(BASEDIR) $(FILESYS)
	@echo -e ""
	$(foreach s, $(SOURCES), @echo -e "$(GREEN)Building $(s)...$(RESET)" ; $(ARMIPS) $(s))
	@echo -e ""
	@echo -e "$(GREEN)Repacking $(BASEROM) to $(BUILDROM)...$(RESET)"
	@$(NDSTOOL) -c $(BUILDROM) $(NDSTOOL_ARGS)

clean:
	rm -rf $(BASEDIR)
	rm -rf $(FILESYS)

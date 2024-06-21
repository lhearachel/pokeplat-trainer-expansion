GREEN := \x1b[1;32m
RESET := \x1b[0;m

BASEDIR := base

BASEROM := pokeplatinum.us.nds
BUILDROM := pokeplatinum.us.patched.nds
XDPATCH := trainerdata.xdelta
FILESYS := filesys
VANILLA := vanilla

NDSTOOL_ARGS := -9 $(BASEDIR)/arm9.bin -7 $(BASEDIR)/arm7.bin -y9 $(BASEDIR)/y9.bin -y7 $(BASEDIR)/y7.bin -d $(FILESYS) -y $(BASEDIR)/overlay -t $(BASEDIR)/banner.bin -h $(BASEDIR)/header.bin

SOURCES := $(wildcard *.s)

all: it patch

include tools.mk

$(BASEDIR):
	@mkdir -p $(BASEDIR)

$(VANILLA):
	@mkdir -p $(VANILLA)

$(FILESYS):
	@mkdir -p $(FILESYS)

unpack-rom: $(NDSTOOL) | $(BASEDIR) $(FILESYS)
ifneq ("$(wildcard $(BASEROM))", "")
	@printf "$(GREEN)Unpacking $(BASEROM)...$(RESET)\n"
	@$(NDSTOOL) -x $(BASEROM) $(NDSTOOL_ARGS)
else
	@printf "$(RED)$(BASEROM) not found; cannot unpack$(RESET)\n"
endif

backup: | $(BASEDIR) $(VANILLA)
	@printf "$(GREEN)Backing up files...$(RESET)\n"
	@cp $(BASEDIR)/arm9.bin $(VANILLA)/arm9.bin

it: tools unpack-rom backup $(SOURCES) | $(BASEDIR) $(FILESYS)
	$(foreach s, $(SOURCES), @printf "$(GREEN)Building $(s)...$(RESET)\n" ; $(ARMIPS) $(s))
	@printf "$(GREEN)Repacking $(BASEROM) to $(BUILDROM)...$(RESET)\n"
	@$(NDSTOOL) -c $(BUILDROM) $(NDSTOOL_ARGS)

patch:
	@printf "$(GREEN)Generating arm9 patch...$(RESET)\n"
	xdelta3 -e -f -s $(VANILLA)/arm9.bin $(BASEDIR)/arm9.bin trainer_expansion.xdelta

dump:
	@hexdump -X -s 0x793B8 -n 0x410 --no-squeezing base/arm9.bin | tr -s ' ' | cut -d ' ' -f 2- | head -n -1

clean: clean-tools
	rm -rf $(BASEDIR)
	rm -rf $(FILESYS)
	rm -rf $(VANILLA)
	rm -rf $(BUILDROM)
	rm -rf $(wildcard *.xdelta)

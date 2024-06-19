TOOLS := tools
NDSTOOL := $(TOOLS)/ndstool/ndstool
ARMIPS := $(TOOLS)/armips/build/armips

update-tools:
	git submodule update --init --recursive

$(NDSTOOL):
	@echo -e "$(GREEN)Building ndstool...$(RESET)"
	@cd $(TOOLS)/ndstool ; ./autogen.sh
	@cd $(TOOLS)/ndstool ; ./configure
	@cd $(TOOLS)/ndstool ; make

$(ARMIPS):
	@echo -e "$(GREEN)Building armips...$(RESET)"
	@cd $(TOOLS)/armips  ; mkdir -p build
	@cd $(TOOLS)/armips/build ; cmake -DCMAKE_BUILD_TYPE=Release ..
	@cd $(TOOLS)/armips/build ; cmake --build .

tools: update-tools $(NDSTOOL) $(ARMIPS)

clean-tools:
	rm -rf $(TOOLS)/ndstool
	rm -rf $(TOOLS)/armips


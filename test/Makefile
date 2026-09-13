PYTHON ?= python3
.PHONY: all clean
all:
	@test "$(GATES)" = yes || { echo "Use root Makefile for RTL; this entry is for GATES=yes"; exit 2; }
	@$(PYTHON) ../scripts/run_tt_gatelevel.py
clean:
	$(RM) results.xml

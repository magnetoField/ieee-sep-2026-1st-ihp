PYTHON ?= python3

.PHONY: upload-check upload-package
upload-check:
	@$(PYTHON) scripts/prepare_upload.py

upload-package: upload-check
	@$(PYTHON) scripts/prepare_upload.py --archive

.PHONY: wiki-build wiki-serve
WIKI_PYTHON ?= .tools/wiki-env/bin/python
wiki-build:
	@$(WIKI_PYTHON) -m mkdocs build --strict --config-file wiki/mkdocs.yml

wiki-serve:
	@$(WIKI_PYTHON) -m mkdocs serve --dev-addr 127.0.0.1:8000 --config-file wiki/mkdocs.yml

.PHONY: doctor lint test-model test-unit test-integration test-exhaustive \
	test-params formal test-mutations coverage synth synth-core synth-ihp area-module synth-sky130 \
	harden test-gatelevel release-check

doctor:
	@$(PYTHON) scripts/doctor.py

lint:
	@$(PYTHON) -m compileall -q model scripts test
	@scripts/local_tool.sh iverilog -g2005 -Wall -s tt_um_rumcajs -t null src/*.v
	@scripts/local_tool.sh yosys -q -p 'read_verilog src/*.v; hierarchy -check -top tt_um_rumcajs; proc; check'
	@scripts/local_tool.sh verilator --lint-only --timing -Wall --top-module tt_um_rumcajs src/*.v

test-model:
	@$(PYTHON) -m unittest discover -s test/model -p 'test_*.py' -v

test-unit:
	@$(PYTHON) scripts/run_unit.py $(if $(MODULE),--module $(MODULE),) $(if $(SEED),--seed $(SEED),)

test-integration:
	@$(PYTHON) -c 'from scripts.run_unit import run_integration,run_wrapper,run_fault_sessions,run_random_sessions; run_integration(); run_wrapper(); run_fault_sessions(); run_random_sessions()'

test-exhaustive:
	@$(PYTHON) -m unittest test.model.test_keypad_network.KeypadNetworkTests.test_all_static_masks -v
	@$(PYTHON) scripts/run_unit.py --module kb_exhaustive

test-params:
	@$(PYTHON) scripts/check_parameters.py

formal:
	@scripts/run_formal.sh

test-mutations:
	@$(PYTHON) scripts/test_mutations.py

coverage:
	@$(PYTHON) scripts/run_coverage.py

synth-core:
	@scripts/local_tool.sh yosys -q -l reports/logs/synth-szymon.log \
		-p 'read_verilog src/szymon.v; synth -top szymon; stat'

synth:
	@scripts/local_tool.sh yosys -q -l reports/logs/synth-top.log \
		-p 'read_verilog src/*.v; synth -top tt_um_rumcajs; stat; check'

synth-sky130:
	@scripts/synth_sky130.sh

synth-ihp:
	@scripts/synth_ihp.sh

area-module:
	@test -n "$(MODULE)" || { echo "usage: make area-module MODULE=szymon_fixed" >&2; exit 2; }
	@scripts/estimate_ihp_module.sh "$(MODULE)"

harden:
	@scripts/harden_ihp.sh

test-gatelevel: synth-ihp
	@scripts/test_gatelevel_ihp.sh

release-check:
	@$(PYTHON) scripts/release_check.py

.PHONY: precheck
precheck:
	@bash scripts/run_precheck.sh $(if $(GDS),"$(GDS)",)

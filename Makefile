EMACS = emacs
CASK = EMACS=${EMACS} cask
DEPENDENCIES = .cask/
SCOPIFIER_PORT = $$(lsof -t -i :6969)
KILL_SCOPIFIER = if [ -n "${SCOPIFIER_PORT}" ]; then kill ${SCOPIFIER_PORT}; fi

all: uncompile compile test

bench: ${DEPENDENCIES}
	${CASK} exec ${EMACS} -Q \
	-L . \
	-l context-coloring \
	-l benchmark/context-coloring-benchmark.el \
	-f context-coloring-benchmark-run

compile: ${DEPENDENCIES}
	${CASK} exec ${EMACS} -Q -batch \
	-L . \
	-f batch-byte-compile *.el

uncompile:
	rm -f *.elc

clean: uncompile
	rm -rf ${DEPENDENCIES}

${DEPENDENCIES}:
	${CASK}

test: ${DEPENDENCIES}
	${KILL_SCOPIFIER}
	${CASK} exec ${EMACS} -Q -batch \
	-L . \
	-l ert \
	-l ert-async \
	-l test/context-coloring-coverage.el \
	-f context-coloring-coverage-ci-init \
	-l test/context-coloring-test.el \
	-f ert-run-tests-batch-and-exit

cover: ${DEPENDENCIES}
	${KILL_SCOPIFIER}
	${CASK} exec ${EMACS} -Q -batch \
	-L . \
	-l ert \
	-l ert-async \
	-l test/context-coloring-coverage.el \
	-f context-coloring-coverage-local-init \
	-l test/context-coloring-test.el \
	-f ert-run-tests-batch-and-exit

.PHONY: all bench compile uncompile clean test cover

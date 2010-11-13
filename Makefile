# Makefile for psycopg2. Do you want to...
#
# Build the library::
#
#   make
#
# Build the documentation::
#
#   make env
#   make docs
#
# Create a source package::
#
#   make env  # required to build the documentation
#   make sdist
#
# Run the test::
#
#   make check  # but this requires setting up a test database with the correct user)
#
# or
#
#   make runtests  # requires the TESTDB in place

PYTHON := python$(PYTHON_VERSION)
PYTHON_VERSION ?= $(shell $(PYTHON) -c 'import sys; print "%d.%d" % sys.version_info[:2]')
ENV_DIR = $(shell pwd)/env/py-$(PYTHON_VERSION)
BUILD_DIR = $(shell pwd)/build/lib.$(PYTHON_VERSION)

TESTDB = psycopg2_test

SOURCE_C := $(wildcard psycopg/*.c psycopg/*.h)
SOURCE_PY := $(wildcard lib/*.py)
SOURCE_DOC := $(wildcard doc/src/*.rst)

PACKAGE := $(BUILD_DIR)/psycopg2
PLATLIB := $(PACKAGE)/_psycopg.so
PURELIB := $(patsubst lib/%,$(PACKAGE)/%,$(SOURCE_PY))

VERSION := $(shell grep PSYCOPG_VERSION setup.py | head -1 | sed -e "s/.*'\(.*\)'/\1/")
SDIST := dist/psycopg2-$(VERSION).tar.gz

EASY_INSTALL = PYTHONPATH=$(ENV_DIR)/lib $(ENV_DIR)/bin/easy_install-$(PYTHON_VERSION) -d $(ENV_DIR)/lib -s $(ENV_DIR)/bin
EZ_SETUP = $(ENV_DIR)/bin/ez_setup.py

.PHONY: env check runtests clean

default: package

all: package runtests sdist

package: $(PLATLIB) $(PURELIB)

docs: docs-html docs-txt

docs-html: doc/html/index.html

docs-txt: doc/psycopg2.txt

sdist: $(SDIST)

runtests: package
	PSYCOPG2_TESTDB=$(TESTDB) PYTHONPATH=$(BUILD_DIR):. $(PYTHON) tests/__init__.py --verbose


# The environment is currently required to build the documentation.
# It is not clean by 'make clean'

env: easy_install
	mkdir -p $(ENV_DIR)/bin
	mkdir -p $(ENV_DIR)/lib
	$(EASY_INSTALL) docutils
	$(EASY_INSTALL) sphinx

easy_install: ez_setup
	PYTHONPATH=$(ENV_DIR)/lib $(PYTHON) $(EZ_SETUP) -d $(ENV_DIR)/lib -s $(ENV_DIR)/bin setuptools

ez_setup: $(EZ_SETUP)

$(EZ_SETUP):
	wget -O $@ http://peak.telecommunity.com/dist/ez_setup.py

check:
	$(MAKE) testdb
	$(MAKE) runtests

testdb:
	@echo "* Creating $(TESTDB)"
	@if psql -l | grep -q " $(TESTDB) "; then \
	    dropdb $(TESTDB) >/dev/null; \
	fi
	createdb $(TESTDB)
	# Note to packagers: this requires the postgres user running the test
	# to be a superuser.  You may change this line to use the superuser only
	# to install the contrib.  Feel free to suggest a better way to set up the
	# testing environment (as the current is enough for development).
	psql -f `pg_config --sharedir`/contrib/hstore.sql $(TESTDB)


$(PLATLIB): $(SOURCE_C)
	$(PYTHON) setup.py build --build-lib $(BUILD_DIR)

$(PACKAGE)/%.py: lib/%.py
	$(PYTHON) setup.py build --build-lib $(BUILD_DIR)


$(SDIST): docs MANIFEST
	$(PYTHON) setup.py sdist --formats=gztar

MANIFEST: MANIFEST.in
	# Run twice as MANIFEST.in includes MANIFEST
	$(PYTHON) setup.py sdist --manifest-only
	$(PYTHON) setup.py sdist --manifest-only

# docs depend on the build as it partly use introspection.
doc/html/index.html: package $(SOURCE_DOC)
	PYTHONPATH=$(ENV_DIR)/lib:$(BUILD_DIR) $(MAKE) SPHINXBUILD=$(ENV_DIR)/bin/sphinx-build -C doc html

doc/psycopg2.txt: package $(SOURCE_DOC)
	PYTHONPATH=$(ENV_DIR)/lib:$(BUILD_DIR) $(MAKE) SPHINXBUILD=$(ENV_DIR)/bin/sphinx-build -C doc text


clean:
	rm -rf build MANIFEST
	$(MAKE) -C doc clean

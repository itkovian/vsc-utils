# Extract values from pyproject.toml
NAME := $(shell python3 -c "import tomllib;print(tomllib.load(open('pyproject.toml','rb'))['project']['name'])")
VERSION := $(shell python3 -c "import tomllib;print(tomllib.load(open('pyproject.toml','rb'))['project']['version'])")
BINARIES := $(shell python3 -c "import tomllib;data=tomllib.load(open('pyproject.toml','rb'));print(' '.join(data['tool']['poetry']['scripts'].keys()))")

PREFIX=/opt/$(NAME)
VENV_DIR=$(PREFIX)/venv
BUILDROOT=$(PWD)/buildroot
WHEELHOUSE=$(PWD)/wheelhouse
DISTNAME=$(subst -,_,$(NAME))


all: rpm

show-vars:
	@echo NAME=$(NAME)
	@echo VERSION=$(VERSION)
	@echo BINARIES=$(BINARIES)

clean:
	rm -rf $(BUILDROOT) dist $(WHEELHOUSE) *.rpm requirements.txt

# Step 1: wheeeeeeelie
wheel:
	poetry build -f wheel

poetry.lock:
	poetry lock

# Step 2: Export requirements.txt from Poetry (includes git deps, pinned to commit)
requirements.txt: pyproject.toml poetry.lock
	@if poetry export --help >/dev/null 2>&1; then \
	    echo "Using poetry export..."; \
	    poetry export --without-hashes --format=requirements.txt --output $@; \
	elif command -v uv >/dev/null 2>&1; then \
	    echo "Using uv export..."; \
	    uv export --no-hashes > $@; \
	else \
	    echo "ERROR: Neither 'poetry export' nor 'uv export' is available. Please install poetry-plugin-export or uv." >&2; \
	    exit 1; \
	fi

# Step 3: Build wheels for all dependencies (including Git-based ones)
wheelhouse: requirements.txt wheel
		rm -rf $(WHEELHOUSE)
		mkdir -p $(WHEELHOUSE)
		pip wheel -r requirements.txt -w $(WHEELHOUSE)
		cp dist/$(DISTNAME)-$(VERSION)-*.whl $(WHEELHOUSE)/

# Step 4: Create venv and install ONLY from wheelhouse
venv: wheelhouse
		rm -rf $(BUILDROOT)
		mkdir -p $(BUILDROOT)$(PREFIX)
		python3 -m venv $(BUILDROOT)$(VENV_DIR)
		. $(BUILDROOT)$(VENV_DIR)/bin/activate && \
		    pip install --no-index --find-links=$(WHEELHOUSE) $(NAME)==$(VERSION)
		$(MAKE) fix-shebangs

# Step 5: Fix shebangs inside venv bin/
#

#sd  '1s|^.*python[0-9.]*' '#!$(VENV_DIR)/bin/python3' $$f; \
#

fix-shebangs:
		for f in $(BUILDROOT)$(VENV_DIR)/bin/*; do \
		    if [ -f $$f ] && head -1 $$f | grep -q 'buildroot'; then \
		        echo "Fixing shebang in $$f"; \
				sed -i '1s|^.*python[0-9.]*|#!$(VENV_DIR)/bin/python3|' $$f; \
		    fi \
		done

wrappers: venv
		mkdir -p $(BUILDROOT)/usr/bin
		for bin in $(BINARIES); do \
		    echo '#!/bin/bash' > $(BUILDROOT)/usr/bin/$$bin; \
			echo "exec $(VENV_DIR)/bin/$$bin \"\$$@\"" >> $(BUILDROOT)/usr/bin/$$bin; \
			chmod +x $(BUILDROOT)/usr/bin/$$bin; \
		done

rpm: wrappers
		fpm -s dir -t rpm \
		    -n $(NAME) \
		    -v $(VERSION) \
		    --prefix=/ \
		    -C $(BUILDROOT) .

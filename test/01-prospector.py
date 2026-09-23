#
# Copyright 2016-2026 Ghent University
#
# This file is part of vsc-utils,
# originally created by the HPC team of Ghent University (http://ugent.be/hpc/en),
# with support of Ghent University (http://ugent.be/hpc),
# the Flemish Supercomputer Centre (VSC) (https://www.vscentrum.be),
# the Flemish Research Foundation (FWO) (http://www.fwo.be/en)
# and the Department of Economy, Science and Innovation (EWI) (http://www.ewi-vlaanderen.be/en).
#
# https://github.com/hpcugent/vsc-utils
#
# All rights reserved.
#
"""
Prospector code-quality test, split out from the common import checks
so it can be run/skipped independently.
"""
import pprint
from pathlib import Path
import pytest

from vsc.install.shared_setup import vsc_setup
from vsc.install.commontest import run_prospector, prospector_ignore_paths_add


prospector_ignore_paths_add(".venv")
prospector_ignore_paths_add(".git")


@pytest.fixture(scope="module")
def repo_base_dir():
    # test/01-prospector.py -> repo root is one level up
    return str(Path(__file__).resolve().parent.parent / "src")

def test_prospector(repo_base_dir):
    failures = run_prospector(repo_base_dir)
    assert not failures, f"prospector failures:\n{pprint.pformat(failures)}"

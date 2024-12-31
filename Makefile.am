# Copyright 2013 Google Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# * Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
# * Neither the name of Google Inc. nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

PHONY_TARGETS =

doc_DATA = AUTHORS COPYING NEWS README
noinst_DATA = INSTALL README
EXTRA_DIST = $(doc_DATA) INSTALL README

BUILD_SED = \
	sed -e 's,__SYSBUILD_BINDIR__,$(exec_prefix)/bin,g' \
	    -e 's,__SYSBUILD_DOCDIR__,$(docdir),g' \
	    -e 's,__SYSBUILD_ETCDIR__,$(sysbuild_confdir),g' \
	    -e 's,__SYSBUILD_SHAREDIR__,$(pkgdatadir),g'
BUILD_SCRIPT = \
	$(BUILD_SED) <"$(srcdir)/$${source}" | \
	    $(SHTK_TOOL) build -o "$${target}" -
BUILD_FILE = \
	$(BUILD_SED) <"$(srcdir)/$${source}" >"$${target}.tmp"; \
	mv "$${target}.tmp" "$${target}"
BUILD_TEST = \
	$(BUILD_SED) <"$(srcdir)/$${source}" | \
	    $(SHTK_TOOL) build -m shtk_unittest_main -o "$${target}" -

bin_SCRIPTS = sysbuild
CLEANFILES = sysbuild
EXTRA_DIST += sysbuild.sh
sysbuild: $(srcdir)/sysbuild.sh
	$(AM_V_GEN)source=sysbuild.sh target=sysbuild; \
	$(BUILD_SCRIPT)

bin_SCRIPTS += sysbuild4cron
CLEANFILES += sysbuild4cron
EXTRA_DIST += sysbuild4cron.sh
sysbuild4cron: $(srcdir)/sysbuild4cron.sh
	$(AM_V_GEN)source=sysbuild4cron.sh target=sysbuild4cron; \
	$(BUILD_SCRIPT)

man_MANS = sysbuild.1
CLEANFILES += sysbuild.1
EXTRA_DIST += sysbuild.1.in
sysbuild.1: $(srcdir)/sysbuild.1.in
	$(AM_V_GEN)source=sysbuild.1.in target=sysbuild.1; \
	$(BUILD_FILE)

dist_man_MANS  = sysbuild.conf.5
dist_man_MANS += sysbuild4cron.1

dist_pkgdata_DATA = env.sh

dist_sysbuild_conf_DATA  = default.conf
if HOST_IS_NETBSD
dist_sysbuild_conf_DATA += NetBSD.conf
endif

TESTS = sysbuild_test
check_SCRIPTS = sysbuild_test
CLEANFILES += sysbuild_test
EXTRA_DIST += sysbuild_test.sh
sysbuild_test: $(srcdir)/sysbuild_test.sh
	$(AM_V_GEN)source=sysbuild_test.sh target=sysbuild_test; \
	$(BUILD_TEST)

TESTS += sysbuild4cron_test
check_SCRIPTS += sysbuild4cron_test
CLEANFILES += sysbuild4cron_test
EXTRA_DIST += sysbuild4cron_test.sh
sysbuild4cron_test: $(srcdir)/sysbuild4cron_test.sh
	$(AM_V_GEN)source=sysbuild4cron_test.sh target=sysbuild4cron_test; \
	$(BUILD_TEST)

TESTS_ENVIRONMENT  = PATH=$(abs_top_builddir):$${PATH}
TESTS_ENVIRONMENT += SYSBUILD_SHAREDIR="$(abs_top_srcdir)"
INSTALLCHECK_ENVIRONMENT = PATH=$(prefix)/bin:$${PATH}

installcheck-local:
	$(MAKE) $(AM_MAKEFLAGS) check-TESTS TESTS_ENVIRONMENT="$(INSTALLCHECK_ENVIRONMENT)"

PHONY_TARGETS += clean-all
clean-all:
	GIT="$(GIT)" $(SH) $(srcdir)/admin/clean-all.sh

.PHONY: $(PHONY_TARGETS)

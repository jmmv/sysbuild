# Copyright 2012 Google Inc.
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

shtk_import unittest


# Paths to installed files.
#
# Can be overriden for test purposes only.
: ${SYSBUILD_SHAREDIR="__SYSBUILD_SHAREDIR__"}


# Creates a fake program that records its invocations for later processing.
#
# The fake program, when invoked, will append its arguments to a commands.log
# file in the test case's work directory.
#
# \param binary The path to the program to create.
# \param delegate If set to 'yes', execute the real program afterwards.
create_mock_binary() {
    local binary="${1}"; shift
    local delegate=no
    [ ${#} -eq 0 ] || { delegate="${1}"; shift; }

    cat >"${binary}" <<EOF
#! /bin/sh

logfile="${HOME}/commands.log"
echo "Command: \${0##*/}" >>"\${logfile}"
echo "Directory: \$(pwd)" >>"\${logfile}"
for arg in "\${@}"; do
    echo "Arg: \${arg}" >>"\${logfile}"
done
    echo >>"\${logfile}"
EOF

    if [ "${delegate}" = yes ]; then
        cat >>"${binary}" <<EOF
PATH="${PATH}"
exec "\${0##*/}" "\${@}"
EOF
    fi

    chmod +x "${binary}"
}


# Creates a fake CVS repository with a src and an xsrc module.
#
# \param repository Path to the repository to create.
create_mock_cvsroot() {
    local repository="${1}"; shift

    assert_command -o ignore -e ignore cvs -d "${repository}" init

    mkdir src
    cd src
    create_mock_binary build.sh
    echo "first revision" >file-in-src
    cvs -d "${repository}" import -m "Import." src VENDOR_TAG release_tag
    cd -
    rm -rf src

    mkdir xsrc
    cd xsrc
    echo "first revision" >file-in-xsrc
    cvs -d "${repository}" import -m "Import." xsrc VENDOR_TAG release_tag
    cd -
    rm -rf xsrc
}


# Creates a fake Git repository for the src module.
#
# \param dir Path to the src repository to create.
# \param branch Name of the branch to create.
create_mock_git_src() {
    local dir="${1}"; shift
    local branch="${1}"; shift

    assert_command -o ignore -e ignore git init --bare -b "${branch}" "${dir}"
    git config --global user.email fake@example.com
    git config --global user.name "Fake User"

    assert_command -o ignore -e ignore git clone "${dir}" tmp
    create_mock_binary tmp/build.sh
    echo "first revision" >tmp/file-in-src
    assert_command -o ignore -e ignore -w tmp git add build.sh file-in-src
    assert_command -o ignore -e ignore -w tmp git commit -a -m 'Import'
    assert_command -o ignore -e ignore -w tmp git push
    rm -rf tmp
}


# Creates a fake Git repository for the xsrc module.
#
# \param dir Path to the xsrc repository to create.
# \param branch Name of the branch to create.
create_mock_git_xsrc() {
    local dir="${1}"; shift
    local branch="${1}"; shift

    assert_command -o ignore -e ignore git init --bare -b "${branch}" "${dir}"
    git config --global user.email fake@example.com
    git config --global user.name "Fake User"

    assert_command -o ignore -e ignore git clone "${dir}" tmp
    echo "first revision" >tmp/file-in-xsrc
    assert_command -o ignore -e ignore -w tmp git add file-in-xsrc
    assert_command -o ignore -e ignore -w tmp git commit -a -m 'Import'
    assert_command -o ignore -e ignore -w tmp git push
    rm -rf tmp
}


shtk_unittest_add_test build__custom_dirs
build__custom_dirs_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    create_mock_cvsroot "${mock_cvsroot}"

    create_mock_binary cvs yes
    PATH="$(pwd):${PATH}"

    cat >test.conf <<EOF
BUILD_ROOT=$(pwd)/b
CVSROOT=${mock_cvsroot}
RELEASEDIR=$(pwd)/r
SRCDIR=$(pwd)/s
XSRCDIR=$(pwd)/x
EOF

    SHTK_HW_NCPUS=1 assert_command -o save:stdout -e save:stderr \
        sysbuild -c test.conf build

    assert_file stdin commands.log <<EOF
Command: cvs
Directory: ${HOME}/s/.cvs-checkout
Arg: -d${mock_cvsroot}
Arg: -q
Arg: checkout
Arg: -P
Arg: src

Command: cvs
Directory: ${HOME}/x/.cvs-checkout
Arg: -d${mock_cvsroot}
Arg: -q
Arg: checkout
Arg: -P
Arg: xsrc

Command: build.sh
Directory: ${HOME}/s
Arg: -D${HOME}/b/$(uname -m)/destdir
Arg: -M${HOME}/b/$(uname -m)/obj
Arg: -N2
Arg: -R${HOME}/r
Arg: -T${HOME}/b/$(uname -m)/tools
Arg: -U
Arg: -X${HOME}/x
Arg: -m$(uname -m)
Arg: -x
Arg: release

EOF
}


shtk_unittest_add_test build__defaults
build__defaults_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    create_mock_cvsroot "${mock_cvsroot}"

    create_mock_binary cvs yes
    PATH="$(pwd):${PATH}"

    SHTK_HW_NCPUS=1 assert_command -o save:stdout -e save:stderr sysbuild \
        -c /dev/null -o CVSROOT="${mock_cvsroot}" build

    assert_file stdin commands.log <<EOF
Command: cvs
Directory: ${HOME}/sysbuild/src/.cvs-checkout
Arg: -d${mock_cvsroot}
Arg: -q
Arg: checkout
Arg: -P
Arg: src

Command: build.sh
Directory: ${HOME}/sysbuild/src
Arg: -D${HOME}/sysbuild/$(uname -m)/destdir
Arg: -M${HOME}/sysbuild/$(uname -m)/obj
Arg: -N2
Arg: -R${HOME}/sysbuild/release
Arg: -T${HOME}/sysbuild/$(uname -m)/tools
Arg: -U
Arg: -m$(uname -m)
Arg: release

EOF
}


shtk_unittest_add_test build__remove_all
build__remove_all_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    create_mock_cvsroot "${mock_cvsroot}"
    mkdir sysbuild
    cd sysbuild
    assert_command -o ignore -e ignore cvs -d"${mock_cvsroot}" checkout -P src
    cd -

    create_mock_binary cvs
    PATH="$(pwd):${PATH}"

    mkdir -p "sysbuild/$(uname -m)/destdir/a"
    mkdir -p "sysbuild/$(uname -m)/obj/b"
    mkdir -p "sysbuild/$(uname -m)/tools/c"
    mkdir -p "sysbuild/$(uname -m)/keep-me"

    assert_command -o save:stdout -e save:stderr sysbuild \
        -c /dev/null -o CVSROOT="${mock_cvsroot}" build

    [ ! -d "sysbuild/$(uname -m)/destdir" ] || fail "destdir not removed"
    [ ! -d "sysbuild/$(uname -m)/obj" ] || fail "obj not removed"
    [ ! -d "sysbuild/$(uname -m)/tools" ] || fail "tools not removed"
    [ -d "sysbuild/$(uname -m)/keep-me" ] || fail "All of buildroot removed"
}


shtk_unittest_add_test build__fast_mode
build__fast_mode_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    create_mock_cvsroot "${mock_cvsroot}"
    mkdir sysbuild
    cd sysbuild
    assert_command -o ignore -e ignore cvs -d"${mock_cvsroot}" checkout -P src
    cd -

    create_mock_binary cvs
    PATH="$(pwd):${PATH}"

    mkdir -p "sysbuild/$(uname -m)/destdir/bin"
    mkdir -p "sysbuild/$(uname -m)/destdir/stand/$(uname -m)/1.2.3"

    SHTK_HW_NCPUS=1 assert_command -o save:stdout -e save:stderr sysbuild \
        -c /dev/null -o CVSROOT="${mock_cvsroot}" build -f

    assert_file stdin commands.log <<EOF
Command: build.sh
Directory: ${HOME}/sysbuild/src
Arg: -D${HOME}/sysbuild/$(uname -m)/destdir
Arg: -M${HOME}/sysbuild/$(uname -m)/obj
Arg: -N2
Arg: -R${HOME}/sysbuild/release
Arg: -T${HOME}/sysbuild/$(uname -m)/tools
Arg: -U
Arg: -m$(uname -m)
Arg: -u
Arg: release

EOF

    [ -d "sysbuild/$(uname -m)/destdir/bin" ] \
        || fail "Deleted a directory that should not have been deleted"
    [ ! -d "sysbuild/$(uname -m)/destdir/stand/$(uname -m)/1.2.3" ] \
        || fail "Obsolete modules not deleted"
}


shtk_unittest_add_test build__many_machines
build__many_machines_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    create_mock_cvsroot "${mock_cvsroot}"

    create_mock_binary cvs yes
    PATH="$(pwd):${PATH}"

    assert_command -o save:stdout -e save:stderr sysbuild \
        -c /dev/null -o CVSROOT="${mock_cvsroot}" \
        -o MACHINES="amd64 macppc shark" -o NJOBS=2 build

    assert_file stdin commands.log <<EOF
Command: cvs
Directory: ${HOME}/sysbuild/src/.cvs-checkout
Arg: -d${mock_cvsroot}
Arg: -q
Arg: checkout
Arg: -P
Arg: src

Command: build.sh
Directory: ${HOME}/sysbuild/src
Arg: -D${HOME}/sysbuild/amd64/destdir
Arg: -M${HOME}/sysbuild/amd64/obj
Arg: -N2
Arg: -R${HOME}/sysbuild/release
Arg: -T${HOME}/sysbuild/amd64/tools
Arg: -U
Arg: -j2
Arg: -mamd64
Arg: release

Command: build.sh
Directory: ${HOME}/sysbuild/src
Arg: -D${HOME}/sysbuild/macppc/destdir
Arg: -M${HOME}/sysbuild/macppc/obj
Arg: -N2
Arg: -R${HOME}/sysbuild/release
Arg: -T${HOME}/sysbuild/macppc/tools
Arg: -U
Arg: -j2
Arg: -mmacppc
Arg: release

Command: build.sh
Directory: ${HOME}/sysbuild/src
Arg: -D${HOME}/sysbuild/shark/destdir
Arg: -M${HOME}/sysbuild/shark/obj
Arg: -N2
Arg: -R${HOME}/sysbuild/release
Arg: -T${HOME}/sysbuild/shark/tools
Arg: -U
Arg: -j2
Arg: -mshark
Arg: release

EOF
}


shtk_unittest_add_test build__machine_targets__ok
build__machine_targets__ok_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    create_mock_cvsroot "${mock_cvsroot}"

    create_mock_binary cvs yes
    PATH="$(pwd):${PATH}"

    assert_command -o save:stdout -e save:stderr sysbuild \
        -c /dev/null -o CVSROOT="${mock_cvsroot}" \
        -o MACHINES="amd64 macppc shark" -o NJOBS=2 build \
        tools macppc:kernel=/foo/bar shark:sets release

    assert_file stdin commands.log <<EOF
Command: cvs
Directory: ${HOME}/sysbuild/src/.cvs-checkout
Arg: -d${mock_cvsroot}
Arg: -q
Arg: checkout
Arg: -P
Arg: src

Command: build.sh
Directory: ${HOME}/sysbuild/src
Arg: -D${HOME}/sysbuild/amd64/destdir
Arg: -M${HOME}/sysbuild/amd64/obj
Arg: -N2
Arg: -R${HOME}/sysbuild/release
Arg: -T${HOME}/sysbuild/amd64/tools
Arg: -U
Arg: -j2
Arg: -mamd64
Arg: tools
Arg: release

Command: build.sh
Directory: ${HOME}/sysbuild/src
Arg: -D${HOME}/sysbuild/macppc/destdir
Arg: -M${HOME}/sysbuild/macppc/obj
Arg: -N2
Arg: -R${HOME}/sysbuild/release
Arg: -T${HOME}/sysbuild/macppc/tools
Arg: -U
Arg: -j2
Arg: -mmacppc
Arg: tools
Arg: kernel=/foo/bar
Arg: release

Command: build.sh
Directory: ${HOME}/sysbuild/src
Arg: -D${HOME}/sysbuild/shark/destdir
Arg: -M${HOME}/sysbuild/shark/obj
Arg: -N2
Arg: -R${HOME}/sysbuild/release
Arg: -T${HOME}/sysbuild/shark/tools
Arg: -U
Arg: -j2
Arg: -mshark
Arg: tools
Arg: sets
Arg: release

EOF
}


shtk_unittest_add_test build__machine_arch_targets__ok
build__machine_arch_targets__ok_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    create_mock_cvsroot "${mock_cvsroot}"

    create_mock_binary cvs yes
    PATH="$(pwd):${PATH}"

    assert_command -o save:stdout -e save:stderr sysbuild \
        -c /dev/null -o CVSROOT="${mock_cvsroot}" \
        -o MACHINES="evbarm-aarch64 evbarm-earmv7hf fake-multi-dashes" \
        -o NJOBS=2 build evbarm-aarch64:sets release

    assert_file stdin commands.log <<EOF
Command: cvs
Directory: ${HOME}/sysbuild/src/.cvs-checkout
Arg: -d${mock_cvsroot}
Arg: -q
Arg: checkout
Arg: -P
Arg: src

Command: build.sh
Directory: ${HOME}/sysbuild/src
Arg: -D${HOME}/sysbuild/evbarm-aarch64/destdir
Arg: -M${HOME}/sysbuild/evbarm-aarch64/obj
Arg: -N2
Arg: -R${HOME}/sysbuild/release
Arg: -T${HOME}/sysbuild/evbarm-aarch64/tools
Arg: -U
Arg: -j2
Arg: -aaarch64
Arg: -mevbarm
Arg: sets
Arg: release

Command: build.sh
Directory: ${HOME}/sysbuild/src
Arg: -D${HOME}/sysbuild/evbarm-earmv7hf/destdir
Arg: -M${HOME}/sysbuild/evbarm-earmv7hf/obj
Arg: -N2
Arg: -R${HOME}/sysbuild/release
Arg: -T${HOME}/sysbuild/evbarm-earmv7hf/tools
Arg: -U
Arg: -j2
Arg: -aearmv7hf
Arg: -mevbarm
Arg: release

Command: build.sh
Directory: ${HOME}/sysbuild/src
Arg: -D${HOME}/sysbuild/fake-multi-dashes/destdir
Arg: -M${HOME}/sysbuild/fake-multi-dashes/obj
Arg: -N2
Arg: -R${HOME}/sysbuild/release
Arg: -T${HOME}/sysbuild/fake-multi-dashes/tools
Arg: -U
Arg: -j2
Arg: -amulti-dashes
Arg: -mfake
Arg: release

EOF
}


shtk_unittest_add_test build__machine_targets__unmatched
build__machine_targets__unmatched_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    create_mock_binary cvs yes
    PATH="$(pwd):${PATH}"

    cat >experr <<EOF
sysbuild: E: The 'macpp:kernel=/foo/bar a:b' targets do not match any machine in 'amd64 macppc shark'
EOF
    assert_command -s exit:1 -o empty -e file:experr sysbuild \
        -c /dev/null -o CVSROOT="${mock_cvsroot}" \
        -o MACHINES="amd64 macppc shark" -o NJOBS=2 build \
        tools macpp:kernel=/foo/bar a:b release

    test ! -f commands.log || fail "cvs should not have been executed"
}


shtk_unittest_add_test build__mkvars
build__mkvars_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    mkdir -p sysbuild/src
    create_mock_binary sysbuild/src/build.sh

    SHTK_HW_NCPUS=1 assert_command -o save:stdout -e save:stderr sysbuild \
        -c /dev/null -o CVSROOT="${mock_cvsroot}" \
        -o MKVARS="MKDEBUG=yes FOO=bar" build -f

    assert_file stdin commands.log <<EOF
Command: build.sh
Directory: ${HOME}/sysbuild/src
Arg: -D${HOME}/sysbuild/$(uname -m)/destdir
Arg: -M${HOME}/sysbuild/$(uname -m)/obj
Arg: -N2
Arg: -R${HOME}/sysbuild/release
Arg: -T${HOME}/sysbuild/$(uname -m)/tools
Arg: -U
Arg: -VMKDEBUG=yes
Arg: -VFOO=bar
Arg: -m$(uname -m)
Arg: -u
Arg: release

EOF
}


shtk_unittest_add_test build__with_x11
build__with_x11_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    create_mock_cvsroot "${mock_cvsroot}"

    create_mock_binary cvs yes
    PATH="$(pwd):${PATH}"

    SHTK_HW_NCPUS=1 assert_command -o save:stdout -e save:stderr sysbuild \
        -c /dev/null -o CVSROOT="${mock_cvsroot}" \
        -o XSRCDIR="${HOME}/sysbuild/xsrc" build

    assert_file stdin commands.log <<EOF
Command: cvs
Directory: ${HOME}/sysbuild/src/.cvs-checkout
Arg: -d${mock_cvsroot}
Arg: -q
Arg: checkout
Arg: -P
Arg: src

Command: cvs
Directory: ${HOME}/sysbuild/xsrc/.cvs-checkout
Arg: -d${mock_cvsroot}
Arg: -q
Arg: checkout
Arg: -P
Arg: xsrc

Command: build.sh
Directory: ${HOME}/sysbuild/src
Arg: -D${HOME}/sysbuild/$(uname -m)/destdir
Arg: -M${HOME}/sysbuild/$(uname -m)/obj
Arg: -N2
Arg: -R${HOME}/sysbuild/release
Arg: -T${HOME}/sysbuild/$(uname -m)/tools
Arg: -U
Arg: -X${HOME}/sysbuild/xsrc
Arg: -m$(uname -m)
Arg: -x
Arg: release

EOF
}


shtk_unittest_add_test build__some_args
build__some_args_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    create_mock_cvsroot "${mock_cvsroot}"

    create_mock_binary cvs yes
    PATH="$(pwd):${PATH}"

    SHTK_HW_NCPUS=1 assert_command -o save:stdout -e save:stderr sysbuild \
        -c /dev/null -o CVSROOT="${mock_cvsroot}" build a foo b

    assert_file stdin commands.log <<EOF
Command: cvs
Directory: ${HOME}/sysbuild/src/.cvs-checkout
Arg: -d${mock_cvsroot}
Arg: -q
Arg: checkout
Arg: -P
Arg: src

Command: build.sh
Directory: ${HOME}/sysbuild/src
Arg: -D${HOME}/sysbuild/$(uname -m)/destdir
Arg: -M${HOME}/sysbuild/$(uname -m)/obj
Arg: -N2
Arg: -R${HOME}/sysbuild/release
Arg: -T${HOME}/sysbuild/$(uname -m)/tools
Arg: -U
Arg: -m$(uname -m)
Arg: a
Arg: foo
Arg: b

EOF
}


shtk_unittest_add_test build__hooks__ok
build__hooks__ok_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    create_mock_cvsroot "${mock_cvsroot}"

    create_mock_binary cvs yes
    PATH="$(pwd):${PATH}"

    cat >test.conf <<EOF
CVSROOT="${mock_cvsroot}"
MACHINES="one two"  # Build hooks are only supposed to be called once.
SRCDIR="$(pwd)/checkout/src"

pre_fetch_hook() {
    echo "Hook before fetch: \${SRCDIR}"
}

post_fetch_hook() {
    echo "Hook after fetch"
}

pre_build_hook() {
    echo "Hook before build: \${MACHINES}"
}

post_build_hook() {
    echo "Hook after build"
}
EOF

    assert_command -o save:stdout -e save:stderr sysbuild -c test.conf build
    grep 'Command: build.sh' commands.log || fail "build.sh not run"

    cat >exp_order <<EOF
Hook before fetch: $(pwd)/checkout/src
Hook after fetch
Hook before build: one two
Hook after build
EOF
    assert_command -o file:exp_order grep '^Hook' stdout
}


shtk_unittest_add_test build__hooks__pre_fail
build__hooks__pre_fail_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    create_mock_cvsroot "${mock_cvsroot}"
    cat >test.conf <<EOF
CVSROOT="${mock_cvsroot}"
SRCDIR="$(pwd)/checkout/src"

pre_fetch_hook() {
    echo "Hook before fetch"
}

post_fetch_hook() {
    echo "Hook after fetch"
}

pre_build_hook() {
    echo "Hook before build"
    false
}

post_build_hook() {
    echo "Hook after build"
}
EOF

    assert_command -s exit:1 -o save:stdout -e save:stderr \
        sysbuild -c test.conf build
    if grep 'Command: build.sh' commands.log; then
        fail "build.sh should not have been run"
    fi

    cat >exp_order <<EOF
Hook before fetch
Hook after fetch
Hook before build
EOF
    assert_command -o file:exp_order grep '^Hook' stdout
}


shtk_unittest_add_test build__hooks__post_fail
build__hooks__post_fail_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    create_mock_cvsroot "${mock_cvsroot}"
    cat >test.conf <<EOF
CVSROOT="${mock_cvsroot}"
SRCDIR="$(pwd)/checkout/src"

pre_build_hook() {
    echo "Hook before build"
}

post_build_hook() {
    echo "Hook after build"
    false
}
EOF

    assert_command -s exit:1 -o save:stdout -e save:stderr \
        sysbuild -c test.conf build
    grep 'Command: build.sh' commands.log || fail "build.sh not run"

    cat >exp_order <<EOF
Hook before build
Hook after build
EOF
    assert_command -o file:exp_order grep '^Hook' stdout
}


shtk_unittest_add_test build__cvs_fails
build__cvs_fails_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    create_mock_cvsroot "${mock_cvsroot}"
    mkdir sysbuild
    cd sysbuild
    assert_command -o ignore -e ignore cvs -d"${mock_cvsroot}" checkout -P src
    cd -

    create_mock_binary cvs yes
    PATH="$(pwd):${PATH}"

    assert_command -s exit:1 -o save:stdout -e save:stderr sysbuild \
        -c /dev/null -o CVSROOT="${mock_cvsroot}" -o CVSTAG=invalid build

    assert_file stdin commands.log <<EOF
Command: cvs
Directory: ${HOME}/sysbuild/src
Arg: -d${mock_cvsroot}
Arg: -q
Arg: update
Arg: -d
Arg: -P
Arg: -rinvalid

EOF
}


shtk_unittest_add_test build__unknown_flag
build__unknown_flag_test() {
cat >experr <<EOF
sysbuild: E: Unknown option -Z in build
Type 'man sysbuild' for help
EOF
    assert_command -s exit:1 -e file:experr sysbuild -c /dev/null build -f -Z
}


shtk_unittest_add_test config__builtins
config__builtins_test() {
    cat >expout <<EOF
BUILD_ROOT = ${HOME}/sysbuild
BUILD_TARGETS = release
CVSROOT = :ext:anoncvs@anoncvs.NetBSD.org:/cvsroot
CVSTAG is undefined
GIT_SRC_BRANCH = trunk
GIT_SRC_REPO = https://github.com/NetBSD/src.git
GIT_XSRC_BRANCH = trunk
GIT_XSRC_REPO = https://github.com/NetBSD/xsrc.git
INCREMENTAL_BUILD = false
MACHINES = $(uname -m)
MKVARS is undefined
NJOBS = 123
RELEASEDIR = ${HOME}/sysbuild/release
SCM = cvs
SRCDIR = ${HOME}/sysbuild/src
UPDATE_SOURCES = true
XSRCDIR is undefined
EOF
    SHTK_HW_NCPUS=123 assert_command -o file:expout sysbuild -c /dev/null config
}


shtk_unittest_add_test config__path__components
config__path__components_test() {
    mkdir .sysbuild
    mkdir system
    export SYSBUILD_ETCDIR="$(pwd)/system"

    echo "BUILD_TARGETS=foo" >my-file
    assert_command -o match:"BUILD_TARGETS = foo" sysbuild -c ./my-file config
}


shtk_unittest_add_test config__path__extension
config__path__extension_test() {
    mkdir .sysbuild
    mkdir system
    export SYSBUILD_ETCDIR="$(pwd)/system"

    echo "BUILD_TARGETS=bar" >my-file.conf
    assert_command -o match:"BUILD_TARGETS = bar" sysbuild -c my-file.conf \
        config
}


shtk_unittest_add_test config__name__system_directory
config__name__system_directory_test() {
    mkdir .sysbuild
    mkdir system
    export SYSBUILD_ETCDIR="$(pwd)/system"

    echo "BUILD_TARGETS='some value'" >system/foo.conf
    assert_command -o match:"BUILD_TARGETS = some value" sysbuild -c foo config
}


shtk_unittest_add_test config__name__user_directory
config__name__user_directory_test() {
    mkdir .sysbuild
    mkdir system
    export SYSBUILD_ETCDIR="$(pwd)/system"

    echo "BUILD_TARGETS='some value'" >system/foo.conf
    echo "BUILD_TARGETS='other value'" >.sysbuild/foo.conf
    assert_command -o match:"BUILD_TARGETS = other value" sysbuild -c foo config
}


shtk_unittest_add_test config__name__not_found
config__name__not_found_test() {
    mkdir .sysbuild
    mkdir system
    export SYSBUILD_ETCDIR="$(pwd)/system"

    cat >experr <<EOF
sysbuild: E: Cannot locate configuration named 'foobar'
Type 'man sysbuild' for help
EOF
    assert_command -s exit:1 -o empty -e file:experr sysbuild -c foobar config
}


shtk_unittest_add_test config__overrides
config__overrides_test() {
    cat >custom.conf <<EOF
BUILD_ROOT=/tmp/test
CVSTAG=the-tag-override
EOF

    cat >expout <<EOF
BUILD_ROOT = /tmp/test
BUILD_TARGETS = release
CVSROOT = foo bar
CVSTAG = the-new-tag
GIT_SRC_BRANCH = trunk
GIT_SRC_REPO = https://github.com/NetBSD/src.git
GIT_XSRC_BRANCH = trunk
GIT_XSRC_REPO = https://github.com/NetBSD/xsrc.git
INCREMENTAL_BUILD = false
MACHINES = $(uname -m)
MKVARS is undefined
NJOBS = 88
RELEASEDIR = ${HOME}/sysbuild/release
SCM = cvs
SRCDIR is undefined
UPDATE_SOURCES = true
XSRCDIR is undefined
EOF
    SHTK_HW_NCPUS=99 assert_command -o file:expout sysbuild -c custom.conf \
        -o CVSROOT="foo bar" -o CVSTAG=the-new-tag -o NJOBS=88 -o SRCDIR= config
}


shtk_unittest_add_test config__too_many_args
config__too_many_args_test() {
    cat >experr <<EOF
sysbuild: E: config does not take any arguments
Type 'man sysbuild' for help
EOF
    assert_command -s exit:1 -e file:experr sysbuild -c /dev/null config foo
}


shtk_unittest_add_test env__src_only
env__src_only_test() {
    cat >expout <<EOF
. "${SYSBUILD_SHAREDIR}/env.sh" ;
PATH="/my/root/shark/tools/bin:\${PATH}"
D="/my/root/shark/destdir"
O="/my/root/shark/obj/usr/src"
S="/usr/src"
T="/my/root/shark/tools"
EOF
    assert_command -s exit:0 -o file:expout sysbuild -c /dev/null \
        -o BUILD_ROOT=/my/root -o MACHINES=shark -o SRCDIR=/usr/src env
}


shtk_unittest_add_test env__src_and_xsrc
env__src_and_xsrc_test() {
    cat >expout <<EOF
. "${SYSBUILD_SHAREDIR}/env.sh" ;
PATH="/my/root/i386/tools/bin:\${PATH}"
D="/my/root/i386/destdir"
O="/my/root/i386/obj/a/b/src"
S="/a/b/src"
T="/my/root/i386/tools"
XO="/my/root/i386/obj/d/xsrc"
XS="/d/xsrc"
EOF
    assert_command -s exit:0 -o file:expout sysbuild -c /dev/null \
        -o BUILD_ROOT=/my/root -o MACHINES=i386 -o SRCDIR=/a/b/src \
        -o XSRCDIR=/d/xsrc env
}


shtk_unittest_add_test env__explicit_machine
env__explicit_machine_test() {
    cat >expout <<EOF
. "${SYSBUILD_SHAREDIR}/env.sh" ;
PATH="/my/root/macppc/tools/bin:\${PATH}"
D="/my/root/macppc/destdir"
O="/my/root/macppc/obj/usr/src"
S="/usr/src"
T="/my/root/macppc/tools"
EOF
    assert_command -s exit:0 -o file:expout sysbuild -c /dev/null \
        -o BUILD_ROOT=/my/root -o MACHINES="amd64 i386" -o SRCDIR=/usr/src \
        env macppc
}


shtk_unittest_add_test env__explicit_machine_arch
env__explicit_machine_arch_test() {
    cat >expout <<EOF
. "${SYSBUILD_SHAREDIR}/env.sh" ;
PATH="/my/root/evbarm-aarch64/tools/bin:\${PATH}"
D="/my/root/evbarm-aarch64/destdir"
O="/my/root/evbarm-aarch64/obj/usr/src"
S="/usr/src"
T="/my/root/evbarm-aarch64/tools"
EOF
    assert_command -s exit:0 -o file:expout sysbuild -c /dev/null \
        -o BUILD_ROOT=/my/root -o MACHINES="amd64 evbarm evbarm:aarch64 i386" \
        -o SRCDIR=/usr/src env evbarm-aarch64
}


shtk_unittest_add_test env__eval
env__eval_test() {
    make_one() {
        mkdir -p "${1}"
        touch "${1}/${2}"
    }
    make_one src src.cookie
    make_one xsrc xsrc.cookie
    make_one root/mach/destdir destdir.cookie
    make_one root/mach/tools tools.cookie
    make_one root/mach/"obj$(pwd)"/src src-obj.cookie
    make_one root/mach/"obj$(pwd)"/xsrc xsrc-obj.cookie

    find src xsrc root

    mkdir -p root/mach/tools/bin
    cat >root/mach/tools/bin/nbmake-mach <<EOF
#! /bin/sh
echo "This is nbmake!"
EOF
    chmod +x root/mach/tools/bin/nbmake-mach

    assert_command -s exit:0 -o save:env.sh sysbuild -c /dev/null \
        -o BUILD_ROOT="$(pwd)/root" \
        -o MACHINES="mach" \
        -o SRCDIR="$(pwd)/src" \
        -o XSRCDIR="$(pwd)/xsrc" \
        env

    eval $(cat ./env.sh)

    [ -f "${D}/destdir.cookie" ] || fail "D points to the wrong place"
    [ -f "${O}/src-obj.cookie" ] || fail "O points to the wrong place"
    [ -f "${S}/src.cookie" ] || fail "S points to the wrong place"
    [ -f "${T}/tools.cookie" ] || fail "T points to the wrong place"
    [ -f "${XO}/xsrc-obj.cookie" ] || fail "XO points to the wrong place"
    [ -f "${XS}/xsrc.cookie" ] || fail "XS points to the wrong place"
    assert_command -o inline:"This is nbmake!\n" nbmake-mach

    mkdir -p src/bin/ls
    assert_equal "$(pwd)/root/mach/obj$(pwd)/src/bin/ls" \
        "$(cd src/bin/ls && curobj)"

    mkdir -p xsrc/some/other/dir
    assert_equal "$(pwd)/root/mach/obj$(pwd)/xsrc/some/other/dir" \
        "$(cd xsrc/some/other/dir && curobj)"

    mkdir a
    assert_equal "NOT-FOUND" "$(cd a && curobj)"
    assert_equal "NOT-FOUND" "$(cd /bin && curobj)"
}


shtk_unittest_add_test env__too_many_machines
env__too_many_machines_test() {
    cat >experr <<EOF
sysbuild: E: No machine name provided as an argument and MACHINES contains more than one name
Type 'man sysbuild' for help
EOF
    assert_command -s exit:1 -e file:experr sysbuild -c /dev/null \
        -o MACHINES="amd64 i386" env
}


shtk_unittest_add_test env__too_many_args
env__too_many_args_test() {
    cat >experr <<EOF
sysbuild: E: env takes zero or one arguments
Type 'man sysbuild' for help
EOF
    assert_command -s exit:1 -e file:experr sysbuild -c /dev/null env foo bar
}


shtk_unittest_add_test fetch__cvs__checkout__src_only
fetch__cvs__checkout__src_only_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    create_mock_cvsroot "${mock_cvsroot}"
    cat >test.conf <<EOF
CVSROOT="${mock_cvsroot}"
SRCDIR="$(pwd)/checkout/src"
XSRCDIR=
EOF

    assert_command -o ignore -e not-match:"xsrc" sysbuild -c test.conf fetch
    test -f checkout/src/file-in-src || fail "src not checked out"
    test ! -d checkout/xsrc || fail "xsrc checked out but not requested"
}


shtk_unittest_add_test fetch__cvs__checkout__src_and_xsrc
fetch__cvs__checkout__src_and_xsrc_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    create_mock_cvsroot "${mock_cvsroot}"
    cat >test.conf <<EOF
CVSROOT="${mock_cvsroot}"
SRCDIR="$(pwd)/checkout/src"
XSRCDIR="$(pwd)/checkout/xsrc"
EOF

    assert_command -o ignore -e ignore sysbuild -c test.conf fetch
    test -f checkout/src/file-in-src || fail "src not checked out"
    test -f checkout/xsrc/file-in-xsrc || fail "xsrc not checked out"
}


shtk_unittest_add_test fetch__cvs__update__src_only
fetch__cvs__update__src_only_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    create_mock_cvsroot "${mock_cvsroot}"
    cat >test.conf <<EOF
CVSROOT="${mock_cvsroot}"
SRCDIR="$(pwd)/checkout/src"
XSRCDIR=
EOF

    mkdir checkout
    cd checkout
    assert_command -o ignore -e ignore cvs -d"${mock_cvsroot}" checkout -P src
    cd -

    cp -rf checkout/src src-copy
    cd src-copy
    echo "second revision" >file-in-src
    cvs commit -m "Second revision."
    cd -

    test -f checkout/src/file-in-src || fail "src not present yet"
    if grep "second revision" checkout/src/file-in-src >/dev/null; then
        fail "second revision already present"
    fi

    assert_command -o ignore -e not-match:"xsrc" sysbuild -c test.conf fetch

    grep "second revision" checkout/src/file-in-src >/dev/null \
        || fail "src not updated"
    test ! -d checkout/xsrc || fail "xsrc checked out but not requested"
}


shtk_unittest_add_test fetch__cvs__update__src_and_xsrc
fetch__cvs__update__src_and_xsrc_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    create_mock_cvsroot "${mock_cvsroot}"
    cat >test.conf <<EOF
CVSROOT="${mock_cvsroot}"
SRCDIR="$(pwd)/checkout/src"
XSRCDIR="$(pwd)/checkout/xsrc"
EOF

    mkdir checkout
    cd checkout
    assert_command -o ignore -e ignore cvs -d"${mock_cvsroot}" checkout \
        -P src xsrc
    cd -

    cp -rf checkout/src src-copy
    cd src-copy
    echo "second revision" >file-in-src
    cvs commit -m "Second revision."
    cd -

    cp -rf checkout/xsrc xsrc-copy
    cd xsrc-copy
    echo "second revision" >file-in-xsrc
    cvs commit -m "Second revision."
    cd -

    test -f checkout/src/file-in-src || fail "src not present yet"
    if grep "second revision" checkout/src/file-in-src >/dev/null; then
        fail "second revision already present"
    fi
    test -f checkout/xsrc/file-in-xsrc || fail "xsrc not present yet"
    if grep "second revision" checkout/xsrc/file-in-xsrc >/dev/null; then
        fail "second revision already present"
    fi

    assert_command -o ignore -e ignore sysbuild -c test.conf fetch

    grep "second revision" checkout/src/file-in-src >/dev/null \
        || fail "src not updated"
    grep "second revision" checkout/xsrc/file-in-xsrc >/dev/null \
        || fail "xsrc not updated"
}


shtk_unittest_add_test fetch__cvs__update__src_is_git
fetch__cvs__update__src_is_git_test() {
    mkdir -p checkout/src/.git
    cat >test.conf <<EOF
SCM=cvs
CVSROOT=irrelevant
SRCDIR="$(pwd)/checkout/src"
XSRCDIR=
EOF

    cat >experr <<EOF
sysbuild: E: SCM=cvs but $(pwd)/checkout/src looks like a Git repo
EOF
    assert_command -s exit:1 -o empty -e file:experr sysbuild -c test.conf fetch
}


shtk_unittest_add_test fetch__cvs__update__xsrc_is_git
fetch__cvs__update__xsrc_is_git_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    create_mock_cvsroot "${mock_cvsroot}"
    mkdir -p checkout/xsrc/.git
    cat >test.conf <<EOF
SCM=cvs
CVSROOT="${mock_cvsroot}"
SRCDIR="$(pwd)/checkout/src"
XSRCDIR="$(pwd)/checkout/xsrc"
EOF

    assert_command -s exit:1 \
        -o ignore \
        -e match:"E: SCM=cvs but $(pwd)/checkout/xsrc looks like a Git repo" \
        sysbuild -c test.conf fetch
}


shtk_unittest_add_test fetch__git__update__src_is_cvs
fetch__git__update__src_is_cvs_test() {
    mkdir -p checkout/src/CVS
    cat >test.conf <<EOF
SCM=git
GIT_SRC_REPO="$(pwd)/src.git"
SRCDIR="$(pwd)/checkout/src"
XSRCDIR=
EOF

    cat >experr <<EOF
sysbuild: E: SCM=git but $(pwd)/checkout/src looks like a CVS checkout
EOF
    assert_command -s exit:1 -o empty -e file:experr sysbuild -c test.conf fetch
}


shtk_unittest_add_test fetch__git__update__xsrc_is_cvs
fetch__git__update__xsrc_is_cvs_test() {
    create_mock_git_src "$(pwd)/src.git" trunk
    mkdir -p checkout/xsrc/CVS
    cat >test.conf <<EOF
SCM=git
GIT_SRC_REPO="$(pwd)/src.git"
GIT_XSRC_REPO=irrelevant
SRCDIR="$(pwd)/checkout/src"
XSRCDIR="$(pwd)/checkout/xsrc"
EOF

    assert_command -s exit:1 \
        -o ignore \
        -e match:"E: SCM=git but $(pwd)/checkout/xsrc looks like a CVS checkout" \
        sysbuild -c test.conf fetch
}


shtk_unittest_add_test fetch__git__checkout__src_only
fetch__git__checkout__src_only_test() {
    create_mock_git_src "$(pwd)/src.git" trunk
    cat >test.conf <<EOF
SCM=git
GIT_SRC_REPO="$(pwd)/src.git"
SRCDIR="$(pwd)/checkout/src"
XSRCDIR=
EOF

    assert_command -o ignore -e not-match:"xsrc" sysbuild -c test.conf fetch
    test -f checkout/src/file-in-src || fail "src not checked out"
    test ! -d checkout/xsrc || fail "xsrc checked out but not requested"
}


shtk_unittest_add_test fetch__git__checkout__src_and_xsrc
fetch__git__checkout__src_and_xsrc_test() {
    create_mock_git_src "$(pwd)/src.git" trunk
    create_mock_git_xsrc "$(pwd)/xsrc.git" trunk
    cat >test.conf <<EOF
SCM=git
GIT_SRC_REPO="$(pwd)/src.git"
GIT_XSRC_REPO="$(pwd)/xsrc.git"
SRCDIR="$(pwd)/checkout/src"
XSRCDIR="$(pwd)/checkout/xsrc"
EOF

    assert_command -o ignore -e ignore sysbuild -c test.conf fetch
    test -f checkout/src/file-in-src || fail "src not checked out"
    test -f checkout/xsrc/file-in-xsrc || fail "xsrc not checked out"
}


shtk_unittest_add_test fetch__git__update__src_only
fetch__git__update__src_only_test() {
    create_mock_git_src "$(pwd)/src.git" trunk
    create_mock_git_xsrc "$(pwd)/xsrc.git" trunk
    cat >test.conf <<EOF
SCM=git
GIT_SRC_REPO="$(pwd)/src.git"
SRCDIR="$(pwd)/checkout/src"
XSRCDIR=
EOF

    mkdir checkout
    assert_command -o ignore -e ignore git clone src.git checkout/src

    assert_command -o ignore -e ignore git clone src.git tmp
    echo "second revision" >tmp/file-in-src
    assert_command -o ignore -e ignore -w tmp git commit -a -m 'Second revision'
    assert_command -o ignore -e ignore -w tmp git push
    rm -rf tmp

    test -f checkout/src/file-in-src || fail "src not present yet"
    if grep "second revision" checkout/src/file-in-src >/dev/null; then
        fail "second revision already present"
    fi

    assert_command -o ignore -e not-match:"xsrc" sysbuild -c test.conf fetch

    grep "second revision" checkout/src/file-in-src >/dev/null \
        || fail "src not updated"
    test ! -d checkout/xsrc || fail "xsrc checked out but not requested"
}


shtk_unittest_add_test fetch__git__update__src_and_xsrc
fetch__git__update__src_and_xsrc_test() {
    create_mock_git_src "$(pwd)/src.git" trunk
    create_mock_git_xsrc "$(pwd)/xsrc.git" trunk
    cat >test.conf <<EOF
SCM=git
GIT_SRC_REPO="$(pwd)/src.git"
SRCDIR="$(pwd)/checkout/src"
XSRCDIR="$(pwd)/checkout/xsrc"
EOF

    mkdir checkout
    assert_command -o ignore -e ignore git clone src.git checkout/src
    assert_command -o ignore -e ignore git clone xsrc.git checkout/xsrc

    for m in src xsrc; do
        assert_command -o ignore -e ignore git clone "$m.git" tmp
        echo "second revision" >"tmp/file-in-$m"
        assert_command -o ignore -e ignore -w tmp git commit -a -m 'Second revision'
        assert_command -o ignore -e ignore -w tmp git push
        rm -rf tmp
    done

    test -f checkout/src/file-in-src || fail "src not present yet"
    if grep "second revision" checkout/src/file-in-src >/dev/null; then
        fail "second revision already present"
    fi
    test -f checkout/xsrc/file-in-xsrc || fail "xsrc not present yet"
    if grep "second revision" checkout/xsrc/file-in-xsrc >/dev/null; then
        fail "second revision already present"
    fi

    assert_command -o ignore -e ignore sysbuild -c test.conf fetch

    grep "second revision" checkout/src/file-in-src >/dev/null \
        || fail "src not updated"
    grep "second revision" checkout/xsrc/file-in-xsrc >/dev/null \
        || fail "xsrc not updated"
}


shtk_unittest_add_test fetch__hooks__ok
fetch__hooks__ok_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    create_mock_cvsroot "${mock_cvsroot}"
    cat >test.conf <<EOF
CVSROOT="${mock_cvsroot}"
SRCDIR="$(pwd)/checkout/src"
XSRCDIR="$(pwd)/checkout/xsrc"

pre_fetch_hook() {
    echo "Hook before fetch: \${CVSROOT}"
    test ! -d "${SRCDIR}"
}

post_fetch_hook() {
    test -d "${SRCDIR}"
    echo "Hook after fetch"
}
EOF

    assert_command -o save:stdout -e ignore sysbuild -c test.conf fetch
    test -f checkout/src/file-in-src || fail "src not checked out"
    test -f checkout/xsrc/file-in-xsrc || fail "xsrc not checked out"

    cat >exp_order <<EOF
Hook before fetch: ${mock_cvsroot}
Hook after fetch
EOF
    assert_command -o file:exp_order grep '^Hook' stdout
}


shtk_unittest_add_test fetch__hooks__pre_fail
fetch__hooks__pre_fail_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    create_mock_cvsroot "${mock_cvsroot}"
    cat >test.conf <<EOF
CVSROOT="${mock_cvsroot}"
SRCDIR="$(pwd)/checkout/src"
XSRCDIR="$(pwd)/checkout/xsrc"

pre_fetch_hook() {
    echo "Hook before fetch"
    false
}

post_fetch_hook() {
    echo "Hook after fetch"
}
EOF

    assert_command -s exit:1 -o save:stdout -e save:stderr \
        sysbuild -c test.conf fetch
    grep 'pre_fetch_hook returned an error' stderr || \
        fail "pre_fetch_hook didn't seem to fail"
    test ! -f checkout/src/file-in-src || fail "src checked out"
    test ! -f checkout/xsrc/file-in-xsrc || fail "xsrc checked out"

    cat >exp_order <<EOF
Hook before fetch
EOF
    assert_command -o file:exp_order grep '^Hook' stdout
}


shtk_unittest_add_test fetch__hooks__post_fail
fetch__hooks__post_fail_test() {
    mock_cvsroot=":local:$(pwd)/cvsroot"
    create_mock_cvsroot "${mock_cvsroot}"
    cat >test.conf <<EOF
CVSROOT="${mock_cvsroot}"
SRCDIR="$(pwd)/checkout/src"
XSRCDIR="$(pwd)/checkout/xsrc"

pre_fetch_hook() {
    echo "Hook before fetch"
}

post_fetch_hook() {
    echo "Hook after fetch"
    false
}
EOF

    assert_command -s exit:1 -o save:stdout -e save:stderr \
        sysbuild -c test.conf fetch
    test -f checkout/src/file-in-src || fail "src not checked out"
    test -f checkout/xsrc/file-in-xsrc || fail "xsrc not checked out"
    grep 'post_fetch_hook returned an error' stderr || \
        fail "post_fetch_hook didn't seem to fail"

    cat >exp_order <<EOF
Hook before fetch
Hook after fetch
EOF
    assert_command -o file:exp_order grep '^Hook' stdout
}


shtk_unittest_add_test fetch__too_many_args
fetch__too_many_args_test() {
    cat >experr <<EOF
sysbuild: E: fetch does not take any arguments
Type 'man sysbuild' for help
EOF
    assert_command -s exit:1 -e file:experr sysbuild -c /dev/null fetch foo
}


shtk_unittest_add_test no_command
no_command_test() {
    cat >experr <<EOF
sysbuild: E: No command specified
Type 'man sysbuild' for help
EOF
    assert_command -s exit:1 -e file:experr sysbuild
}


shtk_unittest_add_test unknown_command
unknown_command_test() {
    cat >experr <<EOF
sysbuild: E: Unknown command foo
Type 'man sysbuild' for help
EOF
    assert_command -s exit:1 -e file:experr sysbuild foo
}


shtk_unittest_add_test unknown_flag
unknown_flag_test() {
    cat >experr <<EOF
sysbuild: E: Unknown option -Z
Type 'man sysbuild' for help
EOF
    assert_command -s exit:1 -e file:experr sysbuild -Z
}


shtk_unittest_add_test missing_argument
missing_argument_test() {
    cat >experr <<EOF
sysbuild: E: Missing argument to option -o
Type 'man sysbuild' for help
EOF
    assert_command -s exit:1 -e file:experr sysbuild -o
}

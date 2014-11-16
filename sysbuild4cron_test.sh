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


# Creates a fake program that records its invocations for later processing.
#
# The fake program, when invoked, will append its arguments to a commands.log
# file in the test case's work directory.
#
# \param binary The path to the program to create.
# \param get_stdin Whether to capture stdin or not.
create_mock_binary() {
    local binary="${1}"; shift
    local get_stdin="${1}"; shift

    cat >"${binary}" <<EOF
#! /bin/sh

logfile="${HOME}/commands.log"
echo "Command: \${0##*/}" >>"\${logfile}"
for arg in "\${@}"; do
    echo "Arg: \${arg}" >>"\${logfile}"
done
    [ "${get_stdin}" = no ] || sed -e 's,^,stdin: ,' >>"\${logfile}"
    echo >>"\${logfile}"
EOF
    chmod +x "${binary}"
}


setup_mocks() {
    mkdir bin
    create_mock_binary bin/mail yes
    create_mock_binary bin/sysbuild no
    PATH="$(pwd)/bin:${PATH}"
    SYSBUILD_BINDIR="$(pwd)/bin"; export SYSBUILD_BINDIR
}


shtk_unittest_add_test no_args
no_args_test() {
    setup_mocks
    assert_command sysbuild4cron

    assert_file stdin commands.log <<EOF
Command: sysbuild

EOF
}


shtk_unittest_add_test some_args
some_args_test() {
    setup_mocks
    assert_command sysbuild4cron -- -k -Z foo bar

    assert_file stdin commands.log <<EOF
Command: sysbuild
Arg: -k
Arg: -Z
Arg: foo
Arg: bar

EOF
}


shtk_unittest_add_test sysbuild_fails
sysbuild_fails_test() {
    setup_mocks
    for number in $(seq 150); do
        echo "echo line ${number}" >>bin/sysbuild
    done
    echo "exit 1" >>bin/sysbuild

    assert_command sysbuild4cron a

    name="$(cd sysbuild/log && echo sysbuild4cron.*.log)"
    cat >expout <<EOF
Command: sysbuild
Arg: a

Command: mail
Arg: -s
Arg: sysbuild failure report
Arg: jmmv
stdin: The following command has failed:
stdin: 
stdin:     $(pwd)/bin/sysbuild a
stdin: 
stdin: The output of the failed command has been left in:
stdin: 
stdin:     $(pwd)/sysbuild/log/${name}
stdin: 
stdin: The last 100 of the log follow:
stdin: 
EOF
    for number in $(seq 51 150); do
        echo "stdin: line ${number}" >>expout
    done
    echo >>expout
    assert_file file:expout commands.log
}


shtk_unittest_add_test custom_flags
custom_flags_test() {
    setup_mocks
    echo "exit 1" >>bin/sysbuild

    assert_command sysbuild4cron -l path/to/logs -r somebody@example.net

    name="$(cd path/to/logs && echo sysbuild4cron.*.log)"
    assert_file stdin commands.log <<EOF
Command: sysbuild

Command: mail
Arg: -s
Arg: sysbuild failure report
Arg: somebody@example.net
stdin: The following command has failed:
stdin: 
stdin:     $(pwd)/bin/sysbuild
stdin: 
stdin: The output of the failed command has been left in:
stdin: 
stdin:     $(pwd)/path/to/logs/${name}
stdin: 
stdin: The last 100 of the log follow:
stdin: 

EOF
}


shtk_unittest_add_test capture_out_and_err
capture_out_and_err_test() {
    setup_mocks
    echo "echo foo" >>bin/sysbuild
    echo "echo bar 1>&2" >>bin/sysbuild
    echo "exit 1" >>bin/sysbuild

    assert_command sysbuild4cron

    expect_file match:"stdin: foo" commands.log
    expect_file match:"stdin: bar" commands.log
}


shtk_unittest_add_test unknown_flag
unknown_flag_test() {
    cat >experr <<EOF
sysbuild4cron: E: Unknown option -Z
Type 'man sysbuild4cron' for help
EOF
    assert_command -s exit:1 -e file:experr sysbuild4cron -Z
}

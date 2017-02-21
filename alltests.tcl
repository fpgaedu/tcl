#!/usr/bin/env tclsh
package require tcltest

namespace import ::tcltest::*

# Set interpreter to custom script. Tcltest sources every test script in an
# indipendent sub-interpreter and passes the script name as the first argument.
# If the interpreter would call vivado immediately without addional options,
# vivado would start in gui mode and would not source the script.
if {[file tail [interpreter]] == "vivado"} {
    interpreter "./vivado-source.sh"
}

runAllTests

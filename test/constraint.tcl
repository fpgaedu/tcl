# constraint.tcl
#
#       This file provides the implementation for the fpgaedu::test::constraint
#       package. The main goal is to extend the tcltest package's functionality
#       through the introduction of new constraint keywords. This package does 
#       define a namespace, but the declaration of this package as a requirement
#       triggers the execution of a script that extends the tcltest package.
#
# Copyright 2017 Matthijs Bos <matthijs_vlaarbos@hotmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

lappend auto_path ..

package require Tcl 8.5
package require tcltest 2.3.5

package provide fpgaedu::test::constraint 1.0

# Define test constraint based on whether the Vivado package can be loaded. This
# is used to prevent Vivado-specific tests from failing while being executed
# by a regular Tcl shell in which Vivado's custom commands are not available. 
# Tests constrained by this property are simply skipped when executed outside 
# Vivado.
::tcltest::testConstraint vivado 0
if {[catch {
    package require Vivado 1.2016.3
} errorResult] != 1} {
    # Vivado package available. Script is being executed by the Vivado Tcl
    # interpreter.
    ::tcltest::testConstraint vivado 1
}

# Define test constraint based on whether a Digilent Nexys 4 board is listed as 
# the only device connected to the machine on which the test is being executed. 
# This constrains implies the previously defined vivado constraint.
::tcltest::testConstraint nexys4 0
if {[::tcltest::testConstraint vivado] == 1} {
    if {[catch {
        # Vivado specific section. Get properties for UID and TID for the first
        # connected hw_target.
        open_hw
        current_hw_server [connect_hw_server]
        current_hw_target [lindex [get_hw_targets] 0]
        set tid [get_property TID [current_hw_target]]
        set uid [get_property UID [current_hw_target]]
        # Execute open_hw_target command in order to check that the nexys4 
        # board is actually powered on. This command will return an error 
        # if this is not the case.
        open_hw_target
    }] != 1} {
        # No error in the section above. Now set the nexys4 constraint based on
        # the presence of "Digilent" in UID and "Nexys4" in TID and the 
        # device being the only device connected to the localhost hardware 
        # server. This method for board identification is not officially 
        # documented, but was derived through experimentation.
        if {[llength [get_hw_targets]] == 1 \
                && [llength [get_hw_devices]] == 1 \
                && [string first Digilent $uid] >= 0 \
                && [string first Nexys4 $tid] >= 0} {
            ::tcltest::testConstraint nexys4 1
        }
    }
    # Clean up 
    close_hw_target
    disconnect_hw_server
    close_hw
} 

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

package require Tcl 8.5

package provide fpgaedu::vivado 1.0

namespace eval ::fpgaedu::vivado {
    namespace export vivado
    namespace ensemble create \
            -command vivado \
            -map {
                getHardwareInfo ::fpgaedu::vivado::GetHardwareInfo
                program         ::fpgaedu::vivado::Program
            }
}

# Returns hardware information about the current vivado instance.
proc ::fpgaedu::vivado::GetHardwareInfo {} {

    open_hw
    set server [connect_hw_server]

    set result {}
    dict set result host [get_property HOST $server]
    dict set result port [get_property PORT $server]

    set resultTargets {}
    foreach target [get_hw_targets -of_objects $server] {

        open_hw_target $target

        set resultTarget {}
        dict set resultTarget name [get_property NAME $target]
        dict set resultTarget uid  [get_property UID $target]
        dict set resultTarget tid  [get_property TID $target]

        set resultDevices {}
        foreach device [get_hw_devices -of_objects $target] {
            set resultDevice {}
            dict set resultDevice name [get_property NAME $device]
            dict set resultDevice part [get_property PART $device]
            lappend resultDevices $resultDevices
        }
        dict set resultTarget devices $resultDevices

        lappend resultTargets $resultTarget

        close_hw_target $target
    }

    dict set result targets $resultTargets

    disconnect_hw_server $server
    close_hw

    return $result
}

# Programs a FPGA
proc ::fpgaedu::vivado::Program {bitstreamPath {target {}} {device {}}} {
    
    open_hw
    
    set server [connect_hw_server]

    if {$target == {}} {
        current_hw_target [lindex [get_hw_targets] 0]
    } else {
        current_hw_target $target
    }
    open_hw_target

    if {$device == {}} {
        current_hw_device [lindex [get_hw_devices]]
    }

    set_property PROGRAM.FILE $bitstreamPath [current_hw_device]
    program_hw_devices

    close_hw_target
    disconnect_hw_server
    close_hw
}

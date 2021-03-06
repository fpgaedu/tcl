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
package require Vivado 1.2016.3

package provide fpgaedu::vivado 1.0

namespace eval ::fpgaedu::vivado {
    namespace export vivado

    set commandMap {
        getTargetIdentifiers    ::fpgaedu::vivado::GetTargetIdentifiers
        getDeviceIdentifiers    ::fpgaedu::vivado::GetDeviceIdentifiers
        program                 ::fpgaedu::vivado::Program
    }

    namespace ensemble create -map $commandMap
    namespace ensemble create -command vivado -map $commandMap
}

proc ::fpgaedu::vivado::GetTargetIdentifiers {} {

    open_hw
    current_hw_server [connect_hw_server]
    
    set targets {}

    foreach target [get_hw_targets] {
        lappend targets [get_property NAME $target]
    }

    disconnect_hw_server [current_hw_server]
    close_hw

    return $targets
}

proc ::fpgaedu::vivado::GetDeviceIdentifiers {targetIdentifier} {

    open_hw
    current_hw_server [connect_hw_server]
    current_hw_target [lindex [get_hw_targets -filter "NAME == $targetIdentifier"] 0]

    set devices {}

    open_hw_target [current_hw_target]

    foreach device [get_hw_devices] {
        lappend devices [get_property NAME $device]
    }

    disconnect_hw_server [current_hw_server]
    close_hw

    return $devices
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

# ::fpgaedu::vivado::Program bitstreamPath ?-target target? ?-device device?
proc ::fpgaedu::vivado::Program {bitstreamPath {target {}} {device {}}} {
    
    open_hw
    current_hw_server [connect_hw_server]
    
    if {$target == {}} {
        current_hw_target [lindex [get_hw_targets] 0]
    } else {
        current_hw_target [lindex [get_hw_targets -filter "NAME == $target"] 0]
    }
    open_hw_target
    
    if {$device == {}} {
        current_hw_device [lindex [get_hw_devices] 0]
    } else {
        current_hw_device [lindex [get_hw_devices -filter "NAME == $device"] 0]
    }

    set_property PROGRAM.FILE $bitstreamPath [current_hw_device]
    program_hw_devices

    close_hw_target
    disconnect_hw_server
    close_hw

    return
}

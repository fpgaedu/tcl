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

package provide fpgaedu::json2 1.0

namespace eval ::fpgaedu::json2 {
    namespace export json
    namespace ensemble create \
            -command json \
            -map {
                create  ::fpgaedu::json2::Create
                get     ::fpgaedu::json2::Get
                set     ::fpgaedu::json2::Set
            }
}

# Private procs

# ::fpgaedu::json2::Create variableName type ?value?
proc ::fpgaedu::json2::Create {varName type {value {}}} {
    upvar $varName target

    switch $type {
        object {
            dict set target data {}
            dict set target schema type object
            dict set target schema members {}
        }
        array {
            dict set target data {}
            dict set target schema type array
            dict set target schema members {}
        }
        string {
            dict set target data $value
            dict set target schema type string
        }
        number {
            if {$value != {}} {
                dict set target data $value
            } else {
                dict set target data 0
            }
            dict set target schema type number
        }
        boolean {
            if {$value == {}} {
                error "Value for argument value is required"
            } elseif {![string is boolean $value]} {
                error "Invalid value for argument value"
            }
            dict set target data [string is true $value]
            dict set target schema type boolean
        }
        null {
            dict set target data null
            dict set target schema type null
        }
        default {
            error "Invalid value for argument type"
        }
    }

    return $target
}

# fpgaedu::json2::Get jsonVariable key ?key ...?
proc ::fpgaedu::json2::Get {jsonVariable args} {
    
    set keys [NormalizeKey $args]

    if {[GetType $jsonVariable $args] in {object array}} {
        error "The requested member is not a value type"
    }

    return [dict get $jsonVariable data {*}$keys]
}

# fpgaedu::json2::Set variableName key type ?value?
proc ::fpgaedu::json2::Set {varName args} {

    upvar $varName target

    set key [lrange $args 0 [expr [llength $args] - 3]]
    set type [lindex $args [expr [llength $args] - 2]]
    set value [lindex $args [expr [llength $args] - 1]]

    dict set target data $key $value
    dict set target schema members $key type $type

    if {$type == "object"} {
        dict set target schema members $key members {}
    }
}

proc ::fpgaedu::json2::GetType {jsonVariable args} {
    if {[llength $args] > 0} {
        set keys [NormalizeKey $args]
        set keys [split [join $keys " members "]]
        set keys [linsert $keys 0 members]
    } else {
        set keys {}
    }
    return [dict get $jsonVariable schema {*}$keys type]
}

proc ::fpgaedu::json2::NormalizeKey {args} {
    return [split $args ". "]
}
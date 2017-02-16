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
package require fpgaedu::assert 1.0
package require fpgaedu::json 1.0

package provide fpgaedu::assert::json 1.0

namespace eval ::fpgaedu::assert::json {

    namespace export assertObjectContainsKey \
            assertObjectContainsString

    proc assertObjectContainsKey {json path} {
        if {[catch {
            set data [::fpgaedu::json::parse $json 1]
        } errorResult]} {
            ::fpgaedu::assert::assertionError "Error while parsing json: $errorResult" 1
        }

        if {![dict exists $data {*}$path ]} {
            ::fpgaedu::assert::assertionError "Could not find an entry $path in $json" 1
        }
    }

    proc assertObjectContainsString {json path value} {
        set data [::fpgaedu::json::parse $json 1]
        set schema [::fpgaedu::json::parseSchema $json 1]

        if {![dict exists $data {*}$path ]} {
            ::fpgaedu::assert::assertionError "Could not find an entry $path in $json" 1
        }
        
        if {[dict get $schema {*}$path] != "string"} {
            ::fpgaedu::assert::assertionError "$path in $json is not a string" 1
        }

        if {[dict get $data {*}$path] != $value} {
            ::fpgaedu::assert::assertionError "$path in $json is not $value" 1
        }
    }
}

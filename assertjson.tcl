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

    namespace export assertObjectContainsKey

    proc assertObjectContainsKey {json args} {
        if {[catch {
            set data [::fpgaedu::json::parse $json 1]
        } errorResult]} {
            ::fpgaedu::assert::assertionError "Error while parsing json: $errorResult" 1
        }

        if {![dict exists $data {*}$args ]} {
            ::fpgaedu::assert::assertionError "Could not find $args in $json" 1
        }
    }
}

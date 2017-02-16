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

package provide fpgaedu::assert 1.0

namespace eval ::fpgaedu::assert {
    namespace export assertEquals \
            assertThrows \
            assertTrue \
            assertFalse \
            assertStringContains \
            assertListContains \
            assertDictContains \
            assertDictContainsKey
}

proc ::fpgaedu::assert::assertThrows {body {errorResultName {}}} {
    
    if {[catch {
        # evaluate script body in the caller's context in order to allow for
        # variables to be resolved
        set result [uplevel 1 $body]
    } result] == 1} {
        if {$errorResultName != {}} {
            upvar 1 $errorResultName errorResult
            set errorResult $result
        }
        return
    } else {
        # no error returned
        ::fpgaedu::assert::assertionError "No error returned, instead returned \"$result\"." 1
    }
}

proc ::fpgaedu::assert::assertEquals {actual expected} {
    if {$actual ne $expected} {
        ::fpgaedu::assert::assertionError "expected \"$expected\" but got \"$actual\"" 1
    }
}

proc ::fpgaedu::assert::assertTrue {expr} {
    if {![expr $expr]} {
        ::fpgaedu::assert::assertionError "$expr does not evaluate to a nonzero integer" 1
    }
}

proc ::fpgaedu::assert::assertFalse {expr} {
    if {[expr $expr]} {
        ::fpgaedu::assert::assertionError "$expr does not evaluate to 0" 1
    }
}

proc ::fpgaedu::assert::assertStringContains {string value} {
    
    if {[string first [join $value] [join $string]] == -1} {
        ::fpgaedu::assert::assertionError "String \"$string\" does not contain \"$value\"" 1
    }
}

proc ::fpgaedu::assert::assertListContains {list value} {
    if {$value ni $list} {
        ::fpgaedu::assert::assertionError "List $list does not contain $value" 1
    }
}

proc ::fpgaedu::assert::assertDictContainsKey {dictionary args} {
    set key [lindex $args 0]
    set value [lindex $args 1]

    if {![dict exists $dictionary $key]} {
        ::fpgaedu::assert::assertionError "dictionary does not contain key \"$key\"" 1
    }    
}

proc ::fpgaedu::assert::assertDictContains {dictionary args} {
    set key [lindex $args 0]
    set value [lindex $args 1]

    ::fpgaedu::assert::assertDictContainsKey $dictionary $key $value
    # {*}args

    if {[dict get $dictionary $key] != $value} {
        ::fpgaedu::assert::assertionError "dictionary does not contain value \"$value\" for key \"$key\"" 1
    }
}

proc ::fpgaedu::assert::assertionError {message {level 0}} {
    return -code error -level [expr $level+1] "Assertion error: $message"
}
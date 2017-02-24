# json.tcl
# 
#       This file implements a number of procedures for parsing, Stringifying 
#       and interacting with JSON-formatted data.
#
# Copyright (c) 2014, 2015, 2016 dbohdan
#   Applies to original code from jimhttp library
#
# Copyright (c) 2017 Matthijs Bos <matthijs_vlaarbos@hotmail.com>
#   Applies to modifications to original code
# 
# License: MIT
#
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation  and/or other materials provided with the distribution.
# 3. Neither the names of the copyright holders nor the names of any
#    contributors may be used to endorse or promote products derived from this
#    software without specific prior written permission.
# 
#    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
#    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#    ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
#    LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
#    CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
#    SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
#    INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
#    CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
#    ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#    POSSIBILITY OF SUCH DAMAGE.

package require Tcl 8.5

package provide fpgaedu::json 2.0

namespace eval ::fpgaedu::json {
    namespace export json
    # Define ensemble command mapping
    dict set commandMap create    ::fpgaedu::json::Create
    dict set commandMap get       ::fpgaedu::json::Get
    dict set commandMap set       ::fpgaedu::json::Set
    dict set commandMap contains  ::fpgaedu::json::Contains
    dict set commandMap parse     ::fpgaedu::json::Parse
    dict set commandMap stringify ::fpgaedu::json::Stringify
    # Create ensemble for package name as well as "json" command, such that
    # one may import the "json" command from this package.
    namespace ensemble create -map $commandMap
    namespace ensemble create -command json -map $commandMap
}

# ::fpgaedu::json
#
# Synopsis:
#       ::fpgaedu::json create TYPE ?VALUE?
#       ::fpgaedu::json create object
#       ::fpgaedu::json create array
#       ::fpgaedu::json create string ?VALUE?
#       ::fpgaedu::json create number ?VALUE?
#       ::fpgaedu::json create boolean true|false
#       ::fpgaedu::json create null
#       ::fpgaedu::json get JSON KEY ?-type? ?-json?
#       ::fpgaedu::json set JSON_NAME KEY TYPE ?VALUE?
#       ::fpgaedu::json contains JSON ?-key KEY? ?-type TYPE? ?-value VALUE?
#       ::fpgaedu::json parse DATA 
#       ::fpgaedu::json Stringify JSON

# ::fpgaedu::json::Create variableName type ?value?
proc ::fpgaedu::json::Create {type {value {}}} {

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
            } elseif {[string is true $value]} {
                dict set target data true
            } else {
                dict set target data false
            }
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

# fpgaedu::json::Get JSON KEY ?-value|-type|-json? 
proc ::fpgaedu::json::Get {json {args {}}} {

    set flag "-value"
    set key {}
    
    set argc [llength $args]
    if {$argc == 1} { 
        set arg0 [lindex $args 0]
        #check if first charcter of first arg is "-", indicating a flag
        if {[string first "-" $arg0] >= 0} {
            set key {}
            set flag [lindex $args 0]
        } else {
            set key $arg0
            set flag -value
        }
    } else {
        set key [lindex $args 0]
        set flag [lindex $args 1]
    }

    switch $flag {
        "-value" {
            return [GetValue $json $key]
        }
        "-type" {
            return [GetType $json $key]
        }
        "-json" {
            return [GetJson $json $key]
        }
        default {
            error "Invalid flag. Should be one of: -value, -type, -json"
        }
    }

    set keys [NormalizeKey $key]

    return [dict get $json data {*}$keys]
}

proc ::fpgaedu::json::GetType {json {key {}}} {
    set schemaKey {}
    foreach k [NormalizeKey $key] {
        lappend schemaKey members
        lappend schemaKey $k
    }
    return [dict get $json schema {*}$schemaKey type]
}

proc ::fpgaedu::json::GetValue {json key} {
    # check that the requested key does not point to a structured type (array 
    # or object).
    set type [GetType $json $key]
    if {$type in {object array}} {
        error "Cannot get value for structured type"
    }
    set keys [NormalizeKey $key]
    return [dict get $json data {*}$keys]
}

proc ::fpgaedu::json::GetJson {json key} {
    
    set dataKey [NormalizeKey $key]
    set schemaKey {}
    foreach k $dataKey {
        lappend schemaKey members
        lappend schemaKey $k
    }

    dict set result data [dict get $json data {*}$dataKey]
    dict set result schema [dict get $json schema {*}$schemaKey]

    return $result
}

# fpgaedu::json::Set variableName key type ?value?
proc ::fpgaedu::json::Set {jsonVarName key type {value {}}} {

    upvar $jsonVarName jsonVar

    if {$value eq ""} {
        if {$type eq "null"} {
            set value null
        }
    }

    set dataKey [NormalizeKey $key]
    set schemaKey {}
    foreach k $dataKey {
        lappend schemaKey members
        lappend schemaKey $k
    }

    if {$type eq "json"} {
        set innerData [dict get $value data]
        set innerSchema [dict get $value schema]

        dict set jsonVar data {*}$dataKey $innerData
        dict set jsonVar schema {*}$schemaKey $innerSchema
        
    } else {
        dict set jsonVar data {*}$dataKey $value
        dict set jsonVar schema {*}$schemaKey type $type
    }
}

proc ::fpgaedu::json::Contains {jsonValue args} {
    
    set dataKey {}
    set schemaKey {}

    if {[dict exists $args -key]} {
        set dataKey [NormalizeKey [dict get $args -key]]
        foreach k $dataKey {
            lappend schemaKey members
            lappend schemaKey $k
        }

        if {![dict exists $jsonValue data {*}$dataKey]} {
            return 0
        } elseif {![dict exists $jsonValue schema {*}$schemaKey]} {
            return 0
        }
    }

    if {[dict exists $args -value]} {
        set keyValue [dict get $jsonValue data {*}$dataKey]
        set argValue [dict get $args -value]
        
        if {$keyValue ne $argValue} {
            return 0
        }
    }

    if {[dict exists $args -type]} {
        set keyType [dict get $jsonValue schema {*}$schemaKey type]
        set argType [dict get $args -type]

        if {$keyType ne $argType} {
            return 0
        }
    }

    return 1
}

proc ::fpgaedu::json::NormalizeKey {key} {
    return [split $key "."]
}

proc ::fpgaedu::json::Parse {data} {
    set tokens [Tokenize $data]
    set result [Decode $tokens]
    if {[lindex $result 1] == [llength $tokens]} {
        return [lindex $result 0]
    } else {
        error "trailing garbage after JSON data in [list $str]"
    }
}

# Returns a list consisting of two elements: the Decoded value and a number
# indicating how many tokens from $tokens were consumed to obtain that value.
proc ::fpgaedu::json::Decode {tokens {startingOffset 0}} {
    set i $startingOffset
    set nextToken [list {} {
        uplevel 1 {
            set token [lindex $tokens $i]
            lassign $token type arg
            incr i
        }
    }]
    set errorMessage [list message {
        upvar 1 tokens tokens
        upvar 1 i i
        if {[llength $tokens] - $i > 0} {
            set max 5
            set context [lrange $tokens $i [expr {$i + $max - 1}]]
            if {[llength $tokens] - $i >= $max} {
                lappend context ...
            }
            append message " before $context"
        } else {
            append message " at the end of the token list"
        }
        uplevel 1 [list error $message]
    }]

    apply $nextToken

    if {$type eq "STRING"} {
        set json [Create string $arg]
        return [list $json [expr {$i - $startingOffset}]]
    } elseif {$type eq "NUMBER"} {
        set json [Create number $arg]
        return [list $json [expr {$i - $startingOffset}]]
    } elseif {$type eq "RAW"} {
        if {$arg in {true, false}} {
            set json [Create boolean $arg]
        } else {
            set json [Create null]
        }
        return [list $json [expr {$i - $startingOffset}]]
    } elseif {$type eq "OPEN_CURLY"} {
        # Object.
        set first 1
        set objectJson [Create object]

        while 1 {
            apply $nextToken

            if {$type eq "CLOSE_CURLY"} {
                return [list $objectJson [expr {$i - $startingOffset}]]
            }

            if {!$first} {
                if {$type eq "COMMA"} {
                    apply $nextToken
                } else {
                    apply $errorMessage "object expected a comma, got $token"
                }
            }

            if {$type eq "STRING"} {
                set memberKey $arg
            } else {
                apply $errorMessage "wrong key for object: $token"
            }

            apply $nextToken

            if {$type ne "COLON"} {
                apply $errorMessage "object expected a colon, got $token"
            }

            lassign [Decode $tokens $i] memberJson tokensInValue
            
            Set objectJson $memberKey json $memberJson

            incr i $tokensInValue

            set first 0
        }
    } elseif {$type eq "OPEN_BRACKET"} {
        # Array.
        set arrayJson [Create array]
        set j 0

        while 1 {
            apply $nextToken

            if {$type eq "CLOSE_BRACKET"} {
                return [list $arrayJson [expr {$i - $startingOffset}]]
            }

            if {$j > 0} {
                if {$type eq "COMMA"} {
                    apply $nextToken
                } else {
                    apply $errorMessage "array expected a comma, got $token"
                }
            }

            # Use the last token as part of the value for recursive decoding.
            incr i -1

            lassign [Decode $tokens $i] memberJson tokensInValue

            Set arrayJson $j json $memberJson

            incr i $tokensInValue

            incr j
        }
    } else {
        if {$token eq ""} {
            apply $errorMessage "missing token"
        } else {
            apply $errorMessage "can't parse $token"
        }
    }

    error {this should not be reached}
}



# Transform a JSON blob into a list of tokens.
proc ::fpgaedu::json::Tokenize {json} {
    if {$json eq {}} {
        error {empty JSON input}
    }

    set tokens {}
    for {set i 0} {$i < [string length $json]} {incr i} {
        set char [string index $json $i]
        switch -exact -- $char {
            \" {
                set value [AnalyzeString [string range $json $i end]]
                lappend tokens \
                        [list STRING [subst -nocommand -novariables $value]]

                incr i [string length $value]
                incr i ;# For the closing quote.
            }
            \{ {
                lappend tokens OPEN_CURLY
            }
            \} {
                lappend tokens CLOSE_CURLY
            }
            \[ {
                lappend tokens OPEN_BRACKET
            }
            \] {
                lappend tokens CLOSE_BRACKET
            }
            , {
                lappend tokens COMMA
            }
            : {
                lappend tokens COLON
            }
            { } {}
            \t {}
            \n {}
            \r {}
            default {
                if {$char in {- 0 1 2 3 4 5 6 7 8 9}} {
                    set value [AnalyzeNumber [string range $json $i end]]
                    lappend tokens [list NUMBER $value]
                    incr i [expr {[string length $value] - 1}]
                } elseif {$char in {t f n}} {
                    set value [AnalyzeBooleanOrNull [string range $json $i end]]
                    lappend tokens [list RAW $value]
                    incr i [expr {[string length $value] - 1}]
                } else {
                    error "can't Tokenize value as JSON: [list $json]"
                }
            }
        }
    }
    return $tokens
}

# Return the beginning of $str parsed as "true", "false" or "null".
proc ::fpgaedu::json::AnalyzeBooleanOrNull {str} {
    regexp {^(true|false|null)} $str value
    if {![info exists value]} {
        error "can't parse value as JSON true/false/null: [list $str]"
    }
    return $value
}

# Return the beginning of $str parsed as a JSON string.
proc ::fpgaedu::json::AnalyzeString {str} {
    if {[regexp {^"((?:[^"\\]|\\.)*)"} $str _ result]} {
        return $result
    } else {
        error "can't parse JSON string: [list $str]"
    }
}

# Return $str parsed as a JSON number.
proc ::fpgaedu::json::AnalyzeNumber {str} {
    if {[regexp -- {^-?(?:0|[1-9][0-9]*)(?:\.[0-9]*)?(:?(?:e|E)[+-]?[0-9]*)?} \
            $str result]} {
        #            [][ integer part  ][ optional  ][  optional exponent  ]
        #            ^ sign             [ frac. part]
        return $result
    } else {
        error "can't parse JSON number: [list $str]"
    }
}

proc ::fpgaedu::json::Stringify {jsonValue} {
    switch [Get $jsonValue -type] {
        object {
            set output {}
            set first 1
            set memberKeys [lsort [dict keys [dict get $jsonValue schema members]]]
            foreach key $memberKeys {
                if {$first} {
                    lappend output "\{"
                    set first 0
                } else {
                    lappend output ", "
                }
                lappend output "\"$key\": "
                lappend output [Stringify [Get $jsonValue $key -json]]
            }
            lappend output "\}"
            return [join $output ""]
        }
        array {
            set output {}
            set first 1
            set memberKeys [lsort [dict keys [dict get $jsonValue schema members]]]
            foreach key $memberKeys {
                
                if {$first} {
                    lappend output "\["
                    set first 0
                } else {
                    lappend output ", "
                }
                
                lappend output [Stringify [Get $jsonValue $key -json]]
            }

            lappend output "\]"

            return [join $output ""]
        }
        string {
            set value [Get $jsonValue -value]
            return "\"$value\""
        }
        number {
            return [Get $jsonValue -value]
        }
        boolean {
            return [Get $jsonValue -value]
        }
        null {
            return null
        }
    }
}
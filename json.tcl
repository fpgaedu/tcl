# JSON parser / encoder.
#
# Copyright (C) 2014, 2015, 2016 dbohdan.
#   Applies to original code from jimhttp library
#
# Copyright (C) 2017 Matthijs Bos <matthijs_vlaarbos@hotmail.com>
#   Applies to modifications
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
package provide fpgaedu::json 1.0

namespace eval ::fpgaedu::json {
    variable everyKey *
    variable everyElement N*
}

# Parse the string $str containing JSON into nested Tcl dictionaries.
# numberDictArrays: decode arrays as dictionaries with sequential integers
# starting with zero as keys; otherwise decode them as lists.
proc ::fpgaedu::json::parse {str {numberDictArrays 1}} {
    set tokens [::fpgaedu::json::tokenize $str]
    set result [::fpgaedu::json::decode $tokens $numberDictArrays]
    if {[lindex $result 1] == [llength $tokens]} {
        return [lindex $result 0]
    } else {
        error "trailing garbage after JSON data in [list $str]"
    }
}

proc ::fpgaedu::json::parseSchema {str {numberDictArrays 1}} {
    set tokens [::fpgaedu::json::tokenize $str]
    set result [::fpgaedu::json::decodeSchema $tokens $numberDictArrays]
    if {[lindex $result 1] == [llength $tokens]} {
        return [lindex $result 0]
    } else {
        error "trailing garbage after JSON data in [list $str]"
    }
}

# Serialize nested Tcl dictionaries as JSON.
#
# numberDictArrays: encode dictionaries with keys {0 1 2 3 ...} as arrays, e.g.,
# {0 a 1 b} to ["a", "b"]. If $numberDictArrays is not true stringify will try
# to produce objects from all Tcl lists and dictionaries unless explicitly told
# otherwise in the schema.
#
# schema: data types for the values in $data. $schema consists of nested lists
# and/or dictionaries that mirror the structure of the data in $data. Each value
# in $schema specifies the data type of the corresponding value in $data. The
# type can be one of "array", "boolean", "null", "number", "object" or "string".
# The special dictionary key "*" in any dictionary in $schema sets the default
# data type for every value in the corresponding dictionary in $data. The key
# "N*" does the same for the elements of an array. When $numberDictArrays is
# true setting "*" forces a dictionary to be serialized as an object when it
# would have been serialized as an array by default (e.g., {0 foo 1 bar}). When
# $numberDictArrays is false setting "N*" forces a list to be serialized as an
# array rather than an object. In that case the list must start with
# {N* defaultType type1 type2 ...}.
#
# strictSchema: generate an error if there is no schema for a value in $data.
#
# compact: no decorative whitespace.
proc ::fpgaedu::json::stringify {data {numberDictArrays 1} {schema ""}
        {strictSchema 0} {compact 0}} {
    if {$schema eq "string"} {
        return "\"$data\""
    }

    set validDict [expr {
        [llength $data] % 2 == 0
    }]
    set schemaValidDict [expr {
        [llength $schema] % 2 == 0
    }]

    set schemaForceArray [expr {
        ($schema eq "array") ||
        ([lindex $schema 0] eq $fpgaedu::json::everyElement) ||
        ($numberDictArrays && $schemaValidDict &&
                [dict exists $schema $::fpgaedu::json::everyElement]) ||
        (!$numberDictArrays && $validDict && $schemaValidDict &&
                ([llength $schema] > 0) &&
                (![::fpgaedu::json::subset [dict keys $schema] [dict keys $data]]))
    }]
    set schemaForceObject [expr {
        ($schema eq "object") ||
        ($schemaValidDict && [dict exists $schema $::fpgaedu::json::everyKey])
    }]
    if {([llength $data] <= 1) &&
            !$schemaForceArray && !$schemaForceObject} {
        if {
                ($schema in {"" "number"}) &&
                ([string is integer -strict $data] ||
                        [string is double -strict $data])
        } {
            return $data
        } elseif {
                ($schema in {"" "boolean"}) &&
                ($data in {"true" "false" 0 1})
        } {
            return [string map {0 false 1 true} $data]
        } elseif {
                ($schema in {"" "null"}) &&
                ($data eq "null")
        } {
            return $data
        } elseif {$schema eq ""} {
            return "\"$data\""
        } else {
            error "invalid schema \"$schema\" for value \"$data\""
        }
    } else {
        # Dictionary or list.
        set isArray [expr {
            !$schemaForceObject &&
            (($numberDictArrays && $validDict &&
                            [::fpgaedu::json::isNumberDict $data]) ||
                    (!$numberDictArrays && !$validDict) ||
                    ($schemaForceArray && (!$numberDictArrays || $validDict)))
        }]

        if {$isArray} {
            return [::fpgaedu::json::stringifyArray $data \
                    $numberDictArrays $schema $strictSchema $compact]
        } elseif {$validDict} {
            return [::fpgaedu::json::stringifyObject $data \
                    $numberDictArrays $schema $strictSchema $compact]
        } else {
            error "invalid schema \"$schema\" for list \"$data\""
        }
    }
    error {this should not be reached}
}


### The private API: can change at any time.

## Utility procedures.

# Return 1 if the elements in $a are a subset of those in $b and and 0
# otherwise.
proc ::fpgaedu::json::subset {a b} {
    set keySet {}
    foreach x $a {
        dict set keySet $x 1
    }
    foreach x $b {
        dict unset keySet $x
    }
    return [expr {[llength $keySet] == 0}]
}

## Procedures used by ::fpgaedu::json::stringify.

# Return 1 if the keys in dictionary are numbers 0, 1, 2... and 0 otherwise.
proc ::fpgaedu::json::isNumberDict {dictionary} {
    set i 0
    foreach {key _} $dictionary {
        if {$key != $i} {
            return 0
        }
        incr i
    }
    return 1
}

# Return the value for key $key from $schema if the key is present. Otherwise
# either return the default value "" or, if $strictSchema is true, generate an
# error.
proc ::fpgaedu::json::getSchemaByKey {schema key {strictSchema 0}} {
    if {[dict exists $schema $key]} {
        set valueSchema [dict get $schema $key]
    } elseif {[dict exists $schema $::fpgaedu::json::everyKey]} {
        set valueSchema [dict get $schema $::fpgaedu::json::everyKey]
    } elseif {[dict exists $schema $::fpgaedu::json::everyElement]} {
        set valueSchema [dict get $schema $::fpgaedu::json::everyElement]
    } else {
        if {$strictSchema} {
            error "missing schema for key \"$key\""
        } else {
            set valueSchema {}
        }
    }
}

proc ::fpgaedu::json::stringifyArray {array {numberDictArrays 1} {schema ""}
        {strictSchema 0} {compact 0}} {
    set arrayElements {}
    if {$numberDictArrays} {
        foreach {key value} $array {
            if {($schema eq "") || ($schema eq "array")} {
                set valueSchema {}
            } else {
                set valueSchema [::fpgaedu::json::getSchemaByKey \
                        $schema $key $strictSchema]
            }
            lappend arrayElements [::fpgaedu::json::stringify $value 1 \
                    $valueSchema $strictSchema]
        }
    } else { ;# list arrays
        set defaultSchema ""
        if {[lindex $schema 0] eq $::fpgaedu::json::everyElement} {
            set defaultSchema [lindex $schema 1]
            set schema [lrange $schema 2 end]
        }
        foreach value $array valueSchema $schema {
            if {($schema eq "") || ($schema eq "array")} {
                set valueSchema $defaultSchema
            }
            lappend arrayElements [::fpgaedu::json::stringify $value 0 \
                    $valueSchema $strictSchema $compact]
        }
    }

    if {$compact} {
        set elementSeparator ,
    } else {
        set elementSeparator {, }
    }
    return "\[[join $arrayElements $elementSeparator]\]"
}

proc ::fpgaedu::json::stringifyObject {dictionary {numberDictArrays 1} {schema ""}
        {strictSchema 0} {compact 0}} {
    set objectDict {}
    if {$compact} {
        set elementSeparator ,
        set keyValueSeparator :
    } else {
        set elementSeparator {, }
        set keyValueSeparator {: }
    }

    foreach {key value} $dictionary {
        if {($schema eq "") || ($schema eq "object")} {
            set valueSchema {}
        } else {
            set valueSchema [::fpgaedu::json::getSchemaByKey \
                $schema $key $strictSchema]
        }
        lappend objectDict "\"$key\"$keyValueSeparator[::fpgaedu::json::stringify \
                $value $numberDictArrays $valueSchema $strictSchema $compact]"
    }

    return "{[join $objectDict $elementSeparator]}"
}

## Procedures used by ::fpgaedu::json::parse.

# Returns a list consisting of two elements: the decoded value and a number
# indicating how many tokens from $tokens were consumed to obtain that value.
proc ::fpgaedu::json::decode {tokens numberDictArrays {startingOffset 0}} {
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

    if {$type in {STRING NUMBER RAW}} {
        return [list $arg [expr {$i - $startingOffset}]]
    } elseif {$type eq "OPEN_CURLY"} {
        # Object.
        set object {}
        set first 1

        while 1 {
            apply $nextToken

            if {$type eq "CLOSE_CURLY"} {
                return [list $object [expr {$i - $startingOffset}]]
            }

            if {!$first} {
                if {$type eq "COMMA"} {
                    apply $nextToken
                } else {
                    apply $errorMessage "object expected a comma, got $token"
                }
            }

            if {$type eq "STRING"} {
                set key $arg
            } else {
                apply $errorMessage "wrong key for object: $token"
            }

            apply $nextToken

            if {$type ne "COLON"} {
                apply $errorMessage "object expected a colon, got $token"
            }

            lassign [::fpgaedu::json::decode $tokens $numberDictArrays $i] \
                    value tokensInValue
            lappend object $key $value
            incr i $tokensInValue

            set first 0
        }
    } elseif {$type eq "OPEN_BRACKET"} {
        # Array.
        set array {}
        set j 0

        while 1 {
            apply $nextToken

            if {$type eq "CLOSE_BRACKET"} {
                return [list $array [expr {$i - $startingOffset}]]
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

            lassign [::fpgaedu::json::decode $tokens $numberDictArrays $i] \
                    value tokensInValue
            if {$numberDictArrays} {
                lappend array $j $value
            } else {
                lappend array $value
            }
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

proc ::fpgaedu::json::decodeSchema {tokens numberDictArrays {startingOffset 0}} {
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
        return [list "string" [expr {$i - $startingOffset}]]
    } elseif {$type eq "NUMBER"} {
        return [list "number" [expr {$i - $startingOffset}]]
    } elseif {$type eq "RAW"} {
        if {$arg in {true, false}} {
            return [list "boolean" [expr {$i - $startingOffset}]]
        } else {
            return [list "null" [expr {$i - $startingOffset}]]
        }
    } elseif {$type eq "OPEN_CURLY"} {
        # Object.
        set object {}
        set first 1

        while 1 {
            apply $nextToken

            if {$type eq "CLOSE_CURLY"} {
                return [list $object [expr {$i - $startingOffset}]]
            }

            if {!$first} {
                if {$type eq "COMMA"} {
                    apply $nextToken
                } else {
                    apply $errorMessage "object expected a comma, got $token"
                }
            }

            if {$type eq "STRING"} {
                set key $arg
            } else {
                apply $errorMessage "wrong key for object: $token"
            }

            apply $nextToken

            if {$type ne "COLON"} {
                apply $errorMessage "object expected a colon, got $token"
            }

            lassign [::fpgaedu::json::decodeSchema $tokens $numberDictArrays $i] \
                    value tokensInValue
            lappend object $key $value
            incr i $tokensInValue

            set first 0
        }
    } elseif {$type eq "OPEN_BRACKET"} {
        # Array.
        set array {}
        set j 0

        while 1 {
            apply $nextToken

            if {$type eq "CLOSE_BRACKET"} {
                return [list $array [expr {$i - $startingOffset}]]
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

            lassign [::fpgaedu::json::decodeSchema $tokens $numberDictArrays $i] \
                    value tokensInValue
            if {$numberDictArrays} {
                lappend array $j $value
            } else {
                lappend array $value
            }
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
proc ::fpgaedu::json::tokenize json {
    if {$json eq {}} {
        error {empty JSON input}
    }

    set tokens {}
    for {set i 0} {$i < [string length $json]} {incr i} {
        set char [string index $json $i]
        switch -exact -- $char {
            \" {
                set value [::fpgaedu::json::analyzeString [string range $json $i end]]
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
                    set value [::fpgaedu::json::analyzeNumber \
                            [string range $json $i end]]
                    lappend tokens [list NUMBER $value]

                    incr i [expr {[string length $value] - 1}]
                } elseif {$char in {t f n}} {
                    set value [::fpgaedu::json::analyzeBooleanOrNull \
                            [string range $json $i end]]
                    lappend tokens [list RAW $value]

                    incr i [expr {[string length $value] - 1}]
                } else {
                    error "can't tokenize value as JSON: [list $json]"
                }
            }
        }
    }
    return $tokens
}

# Return the beginning of $str parsed as "true", "false" or "null".
proc ::fpgaedu::json::analyzeBooleanOrNull str {
    regexp {^(true|false|null)} $str value
    if {![info exists value]} {
        error "can't parse value as JSON true/false/null: [list $str]"
    }
    return $value
}

# Return the beginning of $str parsed as a JSON string.
proc ::fpgaedu::json::analyzeString str {
    if {[regexp {^"((?:[^"\\]|\\.)*)"} $str _ result]} {
        return $result
    } else {
        error "can't parse JSON string: [list $str]"
    }
}

# Return $str parsed as a JSON number.
proc ::fpgaedu::json::analyzeNumber str {
    if {[regexp -- {^-?(?:0|[1-9][0-9]*)(?:\.[0-9]*)?(:?(?:e|E)[+-]?[0-9]*)?} \
            $str result]} {
        #            [][ integer part  ][ optional  ][  optional exponent  ]
        #            ^ sign             [ frac. part]
        return $result
    } else {
        error "can't parse JSON number: [list $str]"
    }
}

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

source json.tcl

namespace eval ::fpgaedu::jsonrpc {

}

proc ::fpgaedu::jsonrpc::handle {mapping channel} {

    set id null
    set id-schema null

    if {[catch {
        # read request data
        set request [chan read $channel]
        
        # parse request data
        lassign [::fpgaedu::jsonrpc::parse-request request] data schema

        # validate request
        ::fpgaedu::jsonrpc::validate-request $data $schema

        # extract relevant request members
        set method [dict get $data method]
        set id [dict get $data id]
        set id-schema [dict get $schema id]
        set params {}
        if {dict contains $data params} {
            set params [dict get $data params]
        }

        # find proper handler
        set handler [::fpgaedu::jsonrpc::find-handler $mapping $method]

        # execute handler
        set result [$handler $params]

        set response [::fpgaedu::jsonrpc::stringify-result $result $result-schema \
                $id $id-schema] 
       
        
    } err-result]} {
        # catch error throws in section above
        set error {}
        dict set $error code -32603
        dict set $error message "Internal error"
        dict set $error data {}
        set error-data-schema {}

        if {[dict exists $err-result code] 
                && [dict exists $err-result message]} {
            # $err-result is probably the result of a call to the 
            # ::fpgaedu::jsonrpc::throw proc
            dict set $error code [dict get $err-result code]
            dict set $error message [dict get $err-result message]

            if {dict exists $err-result data} {
                dict set $error data [dict get $err-result data]
                set error-data-schema {}
                set 
            }
        } else {
            dict set $error data err-result
            dict set $error-data-schema string
        }

        set response [::fpgaedu::jsonrpc::stringify-error $error  $id 0 $id-schema]

    chan puts $channel response

    chan close $channel
}

proc ::fpgaedu::jsonrpc::parse-request {data} {

    if {[catch {
        set json [::json::parse $data 0]
        set schema [::json::parse-schema $data 0]
    } err ]} {
        ::fpgaedu::jsonrpc::throw-parse-error $err
    }

    return [list $json $schema]
}

proc ::fpgaedu::jsonrpc::validate-request {data schema} {
    # check jsonrpc member
    if {![dict exists $data jsonrpc]} {
        ::fpgaedu::jsonrpc::throw-invalid-request "Missing member jsonrpc"
    }
    if {[dict get $schema jsonrpc] != string} {
        ::fpgaedu::jsonrpc::throw-invalid-request "Illegal type for member jsonrpc"}
    }
    if {[dict get $data jsonrpc] != "2.0"} {
        ::fpgaedu::jsonrpc::throw-invalid-request "Illegal value for member jsonrpc"}
    }
 
    #check method member
    if {![dict exists $data method]} {
        ::fpgaedu::jsonrpc::throw-invalid-request "Missing member method"}
    }
    if {[dict get $schema method] != string} {
        ::fpgaedu::jsonrpc::throw-invalid-request "Illegal type for member method"}
    }
    if {[dict get $data method] == ""} {
        ::fpgaedu::jsonrpc::throw-invalid-request "Illegal value for member method"}
    }

    #check id member 
    if {[dict exists $data id] \
            && [[dict get $schema id] ni {string number null}]} {

        ::fpgaedu::jsonrpc::throw-invalid-request "Illegal type for id"
    }
}

proc ::fpgaedu::jsonrpc::stringify-result {data data-schema id id-schema} {

   set response {} 
   dict set $response jsonrpc 2.0
   dict set $response id $id
   dict set $response result $data

   set schema {}
   dict set $schema jsonrpc string
   dict set $schema id $id-schema
   dict set $schema result $data-schema

   if {[dict get $response result] eq {}} {
       dict set $response result null
       dict set $schema result null
   }

   ::json::stringify $response 0 $schema 
}

proc ::fpgaedu::jsonrpc::stringify-error {error error-data-schema id id-schema} {

   set response {} 
   dict set $response jsonrpc 2.0
   dict set $response id $id
   dict set $response error $error 

   set schema {}
   dict set $schema jsonrpc string
   dict set $schema id $id-schema
   dict set $schema error code number
   dict set $schema error message string
   if {dict exists $error data} {
       dict set $schema error data $error-data-schema
   }

   return ::json::stringify $response 0 $schema

}

proc ::fpgaedu::jsonrpc::find-handler {mapping, method} {
    try {
        return [dict get $mapping method]
    } on error {result} {
        ::fpgaedu::jsonrpc::throw-unknown-method "Unknown method $method"
    }
}


proc ::fpgaedu::jsonrpc::throw {code message {data {} {data-schema ""}} {

    set message-dict {}
    dict set $message-dict code $code
    dict set $message-dict message $message

    if {$data ne {}} {
        dict set $message-dict data $data 
        if {$data schema ne ""} {
            dict set $message-dict data-schema $data-schema
        }
    }

    error $message-dict
}

proc ::fpgaedu::jsonrpc::throw-parse-error {message {data ""} {data-schema ""}} {
    ::fpgaedu::jsonrpc::throw -32700 $message $data $data-schema
}

proc ::fpgaedu::jsonrpc::throw-invalid-request {message {data ""} {data-schema ""}} {
    ::fpgaedu::jsonrpc::throw -32600 $message $data $data-schema
}

proc ::fpgaedu::jsonrpc::throw-unknown-method {message {data ""} {data-schema ""}} {
    ::fpgaedu::jsonrpc::throw -32601 $message $data $data-schema
}

proc ::fpgaedu::jsonrpc::throw-invalid-params {message {data ""} {data-schema ""}} {
    ::fpgaedu::jsonrpc::throw -32602 $message $data $data-schema
}

proc ::fpgaedu::jsonrpc::throw-internal-error {message {data ""} {data-schema ""}} {
    ::fpgaedu::jsonrpc::throw -32603 $message $data $data-schema
}

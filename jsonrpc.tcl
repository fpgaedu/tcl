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
package require fpgaedu::json 2.0

package provide fpgaedu::jsonrpc 1.0

namespace import ::fpgaedu::json::json

namespace eval ::fpgaedu::jsonrpc {

    namespace export jsonrpc
    
    variable parseErrorCode -32700
    variable invalidRequestErrorCode -32600
    variable unknownMethodErrorCode -32601
    variable invalidParamsErrorCode -32602
    variable internalErrorCode -32603

    namespace ensemble create \
            -command jsonrpc \
            -map {
                map     ::fpgaedu::jsonrpc::Map
                handle  ::fpgaedu::jsonrpc::Handle
                throw   ::fpgaedu::jsonrpc::Throw
            }
}

proc ::fpgaedu::jsonrpc::Map {rpcConfigName rpcMethod handler} {
    upvar $rpcConfigName rpcConfig

    dict set rpcConfig mapping $rpcMethod $handler

    return $rpcConfig
}

proc ::fpgaedu::jsonrpc::Handle {rpcConfig requestData} {

    variable internalErrorCode

    set idJson [json create null]

    if {[catch {
        # parse request data
        set requestJson [ParseRequest $requestData]

        # validate request
        ValidateRequest $requestJson

        # extract relevant request members
        set method [json get $requestJson method]

        if {[json contains $requestJson -key id]} {
            set idJson [json get $requestJson id -json]
        }

        if {[json contains $requestJson -key params]} {
            set paramsJson [json get $requestJson params -json]
        } else {
            set paramsJson [json create null]
        }

        # find proper handler
        set handler [FindHandler $rpcConfig $method]

        # execute handler
        set resultJson [$handler $paramsJson]

        set response [StringifyResult $resultJson $idJson] 


    } errorResult]} {
        puts $errorResult
        # catch error throws in section above
        set errorCode $internalErrorCode 
        set errorMessage "Internal error"
        set errorDataJson {}

        if {[dict exists $errorResult code] 
                && [dict exists $errorResult message]} {
            # $errorResult is probably the result of a call to the 
            # ::fpgaedu::jsonrpc::Throw proc
            set errorCode [dict get $errorResult code]
            set errorMessage [dict get $errorResult message]
            if {[dict exists $errorResult dataJson]} {
                set errorDataJson [dict get $errorResult dataJson]
            }
        } else {
            set errorDataJson [json create string $errorResult]
        }

        set response [StringifyError $errorCode $errorMessage $errorDataJson $idJson]
    }

    return $response
}

# ::fpgaedu::jsonrpc::Throw 
#
#       Returns an error in a specific format. Use of this procedure inside a 
#       handler procedure results in the call being translated into the 
#       proper JSON-RPC response.
#
# Synopsis:
#       ::fpgaedu::jsonrpc::throw TYPE ?-message MSG? ?-dataJson JSON?
#
# Arguments:
#       type    The error type identifier. Must be one of "parseError", 
#               "invalidRequest", "unknownMethod", "invalidParams" or 
#               "internalError"
#
# Options:
#       -errorMessage MSG   The message to return in the JSON-RPC response error 
#                           object's message field. If not provided, a standard
#                           message is set.
#       -errorDataJson JSON The json content to be returned in the JSON-RPC 
#                           response error object's data field. If not provided, 
#                           the error object's data field is omitted. The value 
#                           provided for JSON should provided by the 
#                           fpgaedu::json package.
#
# Results:
#       Causes an error to be retuned. The returned value is a dictionary 
#       containing entries for the keys code, message and optionally data. The 
#       dictionary's entry for "code" contains an integer value that represents
#       the error code as defined in the JSON-RPC spec that corresponts to the 
#       value provided in the type argument.
#
proc ::fpgaedu::jsonrpc::Throw {args} {
    
    set errorResult {}

    switch [dict get $args -code] {
        parseError {
            dict set errorResult code -32700
        }
        invalidRequest {
            dict set errorResult code -32600
        }
        unknownMethod {
            dict set errorResult code -32601
        }
        invalidParams {
            dict set errorResult code -32602
        }
        internalError {
            dict set errorResult code -32603
        }
        default {
            dict set errorResult code [dict get $args -code]
        }
    }

    dict set errorResult message [dict get $args -message]

    if {[dict exists $args -dataJson]} {
        dict set errorResult dataJson [dict get $args -dataJson]
    }
    
    error $errorResult
}



# Private procedures

proc ::fpgaedu::jsonrpc::ParseRequest {requestData} {

    if {[catch {
        set requestJson [json parse $requestData]
    } err ]} {
        Throw -code parseError -message $err
    }

    return $requestJson
}

proc ::fpgaedu::jsonrpc::ValidateRequest {requestJson} {
    # check jsonrpc member
    if {![json contains $requestJson -key jsonrpc]} {
        Throw -code invalidRequest -message "Missing member jsonrpc"
    }
    if {![json contains $requestJson -key jsonrpc -type string]} {
        Throw -code invalidRequest -message "Illegal type for member jsonrpc"
    }
    if {![json contains $requestJson -key jsonrpc -value 2.0]} {
        Throw -code invalidRequest -message "Illegal value for member jsonrpc"
    }
 
    #check method member
    if {![json contains $requestJson -key method]} {
        Throw -code invalidRequest -message "Missing member method"
    }
    if {![json contains $requestJson -key method -type "string"]} {
        Throw -code invalidRequest -message "Illegal type for member method"
    }
    if {[json contains $requestJson -key method -value ""]} {
        Throw -code invalidRequest -message "Illegal value for member method"
    }

    #check params member type, if provided
    set validParamsTypes {object array}
    if {[json contains $requestJson -key params] 
            && [json get $requestJson params -type] ni $validParamsTypes} {
        Throw -code invalidRequest -message "Illegal type for member params."
    }

    #check id member type, if provided
    set validIdTypes {string number null}
    if {[json contains $requestJson -key id] 
            && [json get $requestJson id -type] ni $validIdTypes} {
        Throw -code invalidRequest -message "Illegal type for id"
    }

    return 1
}

proc ::fpgaedu::jsonrpc::StringifyResult {resultJson idJson} {

    set responseJson [json create object]
    json set responseJson jsonrpc string 2.0
    json set responseJson id json $idJson
    json set responseJson result json $resultJson

   return [json stringify $responseJson]
}

proc ::fpgaedu::jsonrpc::StringifyError {errorCode errorMessage errorDataJson \
        idJson} {
    set responseJson [json create object]
    json set responseJson jsonrpc string 2.0
    json set responseJson id json $idJson
    json set responseJson error object
    json set responseJson error.code number $errorCode
    json set responseJson error.message string $errorMessage
   if {$errorDataJson ne {}} {
       json set responseJson error.data json $errorDataJson
   }
   return [json stringify $responseJson]
}

proc ::fpgaedu::jsonrpc::FindHandler {rpcConfig method} {
    if {[catch {
        set handler [dict get $rpcConfig mapping $method]
    } errorResult] == 1} {
        Throw -code unknownMethod -message "No handler set for method $method"
    } else {
        return $handler
    }
}
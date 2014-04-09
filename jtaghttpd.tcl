#!/usr/local/bin/quartus_stp -t
#
# JTAG HTTP Server
# <http://opensource.org/licenses/MIT> (c) 2013 Paulo Matias
#
# Available Services
#   List JTAG interfaces:
#     http://server/
#   List FPGA devices connected to a JTAG interface:
#     http://server/<hardware_id>
#   List altsource_probe instances contained in a FPGA:
#     http://server/<hardware_id>/<device_id>
#   Read hex value from probe:
#     http://server/<hardware_id>/<device_id>/<instance>/get
#   Query the hex value which is currently being supplied to source:
#     http://server/<hardware_id>/<device_id>/<instance>/cur
#   Write new hex value to source:
#     http://server/<hardware_id>/<device_id>/<instance>/<value>
#   where <instance> can be the instance index or the instance name
#

# Based on:
# Simple Sample httpd/1.[01] server
# Stephen Uhler (c) 1996-1997 Sun Microsystems

# Httpd is a global array containing the global server state
#  myaddr:  server-side network interface to use for the connection
#  port:    The port this server is serving
#  listen:  the main listening socket id
#  accepts: a count of accepted connections so far
#  maxtime:     The max time (msec) allowed to complete an http request

# HTTP/1.[01] error codes (the ones we use)

array set HttpdErrors {
    204 {No Content}
    400 {Bad Request}
    404 {Not Found}
    408 {Request Timeout}
    411 {Length Required}
    419 {Expectation Failed}
    503 {Service Unavailable}
    504 {Service Temporarily Unavailable}
    }

array set Httpd {
    bufsize 32768
    maxtime 600000
}

# Start the server by listening for connections on the desired port.

proc Httpd_Server {{myaddr 127.0.0.1} {port 80}} {
    global Httpd

    catch {close Httpd(port)}   ;# it might already be running
    array set Httpd [list myaddr $myaddr port $port]
    array set Httpd [list accepts 0 requests 0 errors 0]
    set Httpd(listen) [socket -server HttpdAccept -myaddr $myaddr $port]
    return $Httpd(port)
}

# Accept a new connection from the server and set up a handler
# to read the request from the client.

proc HttpdAccept {sock ipaddr {port {}}} {
    global Httpd
    upvar #0 Httpd$sock data

    incr Httpd(accepts)
    HttpdReset $sock
    Httpd_Log $sock Connect $ipaddr $port
}

# Initialize or reset the socket state

proc HttpdReset {sock} {
    global Httpd
    upvar #0 Httpd$sock data

    array set data [list state start linemode 1 version 0]
    set data(cancel) [after $Httpd(maxtime) [list HttpdTimeout $sock]]
    fconfigure $sock -blocking 0 -buffersize $Httpd(bufsize) \
    -translation {auto crlf}
    fileevent $sock readable [list HttpdRead $sock]
}

# Read data from a client request
# 1) read the request line
# 2) read the mime headers
# 3) read the additional data (if post && content-length not satisfied)

proc HttpdRead {sock} {
    global Httpd
    upvar #0 Httpd$sock data

    # Use line mode to read the request and the mime headers

    if {$data(linemode)} {
    set readCount [gets $sock line]
    set state [string compare $readCount 0],$data(state)
    switch -glob -- $state {
        1,start {
        if {[regexp {(HEAD|POST|GET) ([^?]+)\??([^ ]*) HTTP/1.([01])} $line \
            x data(proto) data(url) data(query) data(version)]} {
            set data(state) mime
            incr Httpd(requests)
            Httpd_Log $sock Request $line
        } else {
            HttpdError $sock 400 $line
        }
        }
        0,start {
        Httpd_Log $sock Warning "Initial blank line fetching request"
        }
        1,mime {
        if {[regexp {([^:]+):[  ]*(.*)}  $line {} key value]} {
            set key [string tolower $key]
            set data(key) $key
            if {[info exists data(mime,$key)]} {
            append data(mime,$key) ", $value"
            } else {
            set data(mime,$key) $value
            }
        } elseif {[regexp {^[   ]+(.+)} $line {} value] && \
            [info exists data(key)]} {
            append data(mime,$data($key)) " " $value
        } else {
            HttpdError $sock 400 $line
        }
        }
        0,mime {
            if {$data(proto) == "POST" && \
                [info exists data(mime,content-length)]} {
            set data(linemode) 0
                set data(count) $data(mime,content-length)
                if {$data(version) && [info exists data(mime,expect]} {
                    if {$data(mime,expect) == "100-continue"} {
                puts $sock "100 Continue HTTP/1.1\n"
                flush $sock
            } else {
                HttpdError $sock 419 $data(mime,expect)
            }
            }
            fconfigure $sock -translation {binary crlf}
            } elseif {$data(proto) != "POST"}  {
            HttpdRespond $sock
            } else {
            HttpdError $sock 411 "Confusing mime headers"
            }
        }
        -1,* {
            if {[eof $sock]} {
            Httpd_Log $sock Error "Broken connection fetching request"
            HttpdSockDone $sock 1
            } else {
                puts stderr "Partial read, retrying"
            }
        }
        default {
        HttpdError $sock 404 "Invalid http state: $state,[eof $sock]"
        }
    }

    # Use counted mode to get the post data

    } elseif {![eof $sock]} {
        append data(postdata) [read $sock $data(count)]
        set data(count) [expr {$data(mime,content-length) - \
            [string length $data(postdata)]}]
        if {$data(count) == 0} {
        HttpdRespond $sock
    }
    } else {
    Httpd_Log $sock Error "Broken connection reading POST data"
    HttpdSockDone $sock 1
    }
}

# Done with the socket, either close it, or set up for next fetch
#  sock:  The socket I'm done with
#  close: If true, close the socket, otherwise set up for reuse

proc HttpdSockDone {sock close} {
    global Httpd
    upvar #0 Httpd$sock data
    after cancel $data(cancel)
    unset data
    if {$close} {
    close $sock
    } else {
    HttpdReset $sock
    }
    return ""
}

# A timeout happened

proc HttpdTimeout {sock} {
    global Httpd
    upvar #0 Httpd$sock data
    HttpdError $sock 408
}

# Handle file system queries.  This is a place holder for a more
# generic dispatch mechanism.

proc HttpdRespond {sock} {
    global Httpd
    upvar #0 Httpd$sock data

    regsub {(^http://[^/]+)?} $data(url) {} url
    
    if {[catch {solve_url $sock $url contents} result]} {
        set contents "\{\"error\": [json_string $result]\}"
    }
    if { $result == 0 } {
        return
    }

    if {[string length $url] == 0} {
    HttpdError $sock 400
    } else {
    puts $sock "HTTP/1.$data(version) 200 Data follows"
    puts $sock "Date: [HttpdDate [clock seconds]]"
    puts $sock "Cache-Control: no-cache"
    puts $sock "Content-Type: application/json"
    puts $sock "Content-Length: [string length $contents]"

    set close 0
    if {[info exists data(mime,connection)]} {
        if {$data(mime,connection) == "Close"} {
            set close 1
        }
    }

    if {$close} {
        puts $sock "Connection: close"
    } elseif {$data(version) == 0 && [info exists data(mime,connection)]} {
        if {$data(mime,connection) == "Keep-Alive"} {
            set close 0
            puts $sock "Connection: Keep-Alive"
        }
    }
    puts $sock ""
    flush $sock

    if {$data(proto) != "HEAD"} {
        fconfigure $sock -translation binary
        puts -nonewline $sock $contents
        flush $sock
    }
    HttpdSockDone $sock $close
    }
}

# Generic error response.

set HttpdErrorFormat {
    <title>Error: %1$s</title>
    Got the error: <b>%2$s</b><br>
    while trying to obtain <b>%3$s</b>
}

# Respond with an error reply
# sock:  The socket handle to the client
# code:  The httpd error code
# args:  Additional information for error logging

proc HttpdError {sock code args} {
    upvar #0 Httpd$sock data
    global Httpd HttpdErrors HttpdErrorFormat

    append data(url) ""
    incr Httpd(errors)
    set message [format $HttpdErrorFormat $code $HttpdErrors($code) $data(url)]
    append head "HTTP/1.$data(version) $code $HttpdErrors($code)"  \n
    append head "Date: [HttpdDate [clock seconds]]"  \n
    append head "Connection: close"  \n
    append head "Content-Length: [string length $message]"  \n

    # Because there is an error condition, the socket may be "dead"

    catch {
    fconfigure $sock -translation binary
    puts -nonewline $sock $head\n$message
    flush $sock
    } reason
    HttpdSockDone $sock 1
    Httpd_Log $sock Error $code $HttpdErrors($code) $args $reason
}

# Generate a date string in HTTP format.

proc HttpdDate {seconds} {
    return [clock format $seconds -format {%a, %d %b %Y %T %Z}]
}

# Log an Httpd transaction.
# This should be replaced as needed.

proc Httpd_Log {sock args} {
    puts stderr "LOG: $args"
}

# Utility functions

proc Just data { return [list Just $data] }
proc Nothing {} { return [list Nothing] }

proc json_string {str} {
    set quotes [list "\"" "\\\"" / \\/ \\ \\\\ \b \\b \f \\f \n \\n \r \\r \t \\t]
    return "\"[string map $quotes $str]\""
}

# JTAG HTTP server implementation

set hardware_fromid [dict create]
set hardware_toid [dict create]
set hardware_id_counter 0

proc get_hardware_json {} {
    global hardware_fromid hardware_toid hardware_id_counter
    set vec {}
    foreach hardware_name [get_hardware_names] {
        if { ! [dict exists $hardware_toid $hardware_name] } {
            incr hardware_id_counter
            dict set hardware_toid $hardware_name $hardware_id_counter
            dict set hardware_fromid $hardware_id_counter $hardware_name
        }
        lappend vec "\"[dict get $hardware_toid $hardware_name]\":[json_string $hardware_name]"
    }
    return "\{[join $vec ,]\}"
}

proc get_hardware_name {hardware_id} {
    global hardware_fromid
    if { ! [dict exists $hardware_fromid $hardware_id] } {
        get_hardware_json
    }
    return [dict get $hardware_fromid $hardware_id]
}

set device_fromid [dict create]
set device_toid [dict create]
set device_id_counter [dict create]

proc get_device_json {hardware_id} {
    global device_fromid device_toid device_id_counter
    set vec {}
    set hardware_name [get_hardware_name $hardware_id]
    foreach device_name [get_device_names -hardware_name $hardware_name] {
        if { [dict exists $device_toid $hardware_id $device_name] } {
            set curr_id [dict get $device_toid $hardware_id $device_name]
        } else {
            dict incr device_id_counter $hardware_id
            set curr_id [dict get $device_id_counter $hardware_id]
            dict set device_toid $hardware_id $device_name $curr_id
            dict set device_fromid $hardware_id $curr_id $device_name
        }
        lappend vec "\"$curr_id\":[json_string $device_name]"
    }
    return "\{[join $vec ,]\}"
}

proc get_device_name {hardware_id device_id} {
    global device_fromid
    if { ! [dict exists $device_fromid $hardware_id $device_id] } {
        get_device_json $hardware_id
    }
    return [dict get $device_fromid $hardware_id $device_id]
}

set probe_in_progress [Nothing]

proc init_probe {hardware_id device_id} {
    global probe_in_progress
    set need_start 0
    switch -exact [lindex $probe_in_progress 0] {
        Just {
            set data [lindex $probe_in_progress 1]
            if { [lindex $data 0] != $hardware_id || [lindex $data 1] != $device_id } {
                end_insystem_source_probe 
                set need_start 1
            }
        }
        Nothing { set need_start 1 }
    }
    if { $need_start } {
        start_insystem_source_probe -hardware_name [get_hardware_name $hardware_id] -device_name [get_device_name $hardware_id $device_id]
        set probe_in_progress [Just [list $hardware_id $device_id]]
    }
}

proc clear_probe {} {
    global probe_in_progress
    switch -exact [lindex $probe_in_progress 0] {
        Just {
            end_insystem_source_probe
            set probe_in_progress [Nothing]
        }
    }
}

set instance_toid [dict create]

proc get_instance_json {hardware_id device_id} {
    global instance_toid
    set hardware_name [get_hardware_name $hardware_id]
    set device_name [get_device_name $hardware_id $device_id]
    clear_probe ;#needed for get_insystem_source_probe_instance_info to work
    set vec {}
    foreach instance [get_insystem_source_probe_instance_info -hardware_name $hardware_name -device_name $device_name] {
        set instance_id [lindex $instance 0]
        set instance_name [lindex $instance 3]
        dict set instance_toid $hardware_id $device_id $instance_name $instance_id
        lappend vec "\"$instance_id\":\[[json_string $instance_name],[lindex $instance 1],[lindex $instance 2]\]"
    }
    return "\{[join $vec ,]\}"
}

proc solve_instance_id {hardware_id device_id instance} {
    global instance_toid
    if { [string is digit $instance] } {
        return $instance
    }
    if { ! [dict exists $instance_toid $hardware_id $device_id $instance] } {
        get_instance_json $hardware_id $device_id
    }
    return [dict get $instance_toid $hardware_id $device_id $instance]
}

proc solve_url {sock url result} {
    upvar $result contents
    if { [regexp {^/(\d+)/(\d+)/([^/]+)/(get|cur|[[:xdigit:]]+)$} $url {} hardware_id device_id instance option] } {
        set inst [solve_instance_id $hardware_id $device_id $instance]
        init_probe $hardware_id $device_id
        switch $option {
            "get" { set contents "\"[read_probe_data  -instance_index $inst -value_in_hex]\"" }
            "cur" { set contents "\"[read_source_data -instance_index $inst -value_in_hex]\"" }
            default  {
                write_source_data -instance_index $inst -value_in_hex -value $option
                set contents "\"ok\""
            }
        }
    } elseif { [string equal $url "/"] } {
        set contents [get_hardware_json]
    } elseif { [regexp {^/(\d+)/?$} $url {} hardware_id] } {
        set contents [get_device_json $hardware_id]
    } elseif { [regexp {^/(\d+)/(\d+)/?$} $url {} hardware_id device_id] } {
        set contents [get_instance_json $hardware_id $device_id]
    } else {
        HttpdError $sock 404 $url
        return 0
    }
    return 1
}


set myaddr 127.0.0.1
set port 8000

if { $argc == 1 } {
    set port [lindex $argv 0]
} elseif { $argc == 2 } {
    set myaddr [lindex $argv 0]
    set port [lindex $argv 1]
} elseif { $argc != 0 } {
    puts stderr "usage: $argv0 \[\[myaddr\] port\]"
    exit 1
}

Httpd_Server $myaddr $port
puts stderr "Starting jtag http server on $myaddr port $port"
vwait forever       ;# start the Tcl event loop

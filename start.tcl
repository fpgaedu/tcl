
lappend auto_path [file dirname [file normalize [info script]]]

package require fpgaedu::vivadoserver 1.0

namespace import ::fpgaedu::vivadoserver::vivadoserver

vivadoserver start
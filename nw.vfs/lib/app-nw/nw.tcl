package provide app-nw 1.0

package require ncgi

package require app-nw-common
package require app-nw-store
package require app-nw-display

if {![info exists env(PATH_INFO)]} {set env(PATH_INFO) "/Main"}

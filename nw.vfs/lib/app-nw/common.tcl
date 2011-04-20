package provide app-nw-common 1.0

namespace eval timestamp {
	namespace export now ago fuzz pretty
	namespace ensemble create
	
	proc pretty {t} { return "[fuzz [ago $t]] ago" }
	proc now {} { clock seconds }
	proc ago {t} {expr {[clock seconds] - $t}}
	proc s {n} { expr {$n == 1 ? {} : {s}} }
	proc fuzz {t} {
		if {$t < 60} {
			return "$t second[s $t]"
		} elseif {$t < 3600} {
			set t [expr {$t/60}]
			return "$t minute[s $t]"
		} elseif {$t < 86400} {
			set t [expr {$t/3600}]
			return "$t hour[s $t]"
		} elseif {$t < 604800} {
			set t [expr {$t/86400}]
			return "$t day[s $t]"
		} elseif {$t < 2629800} {
			set t [expr {$t/604800}]
			return "$t week[s $t]"
		} elseif {$t < 31557600} {
			set t [expr {$t/2629800}]
			return "$t month[s $t]"
		} else {
			set t [expr {$t/31557600}]
			return "$t year[s $t]"
		}
	}
}

# some functional stuff

proc map {lambda list} {
	uplevel foreach item $list {apply $lambda $item}
}

proc zip {a b} {
	set o {}
	for {set k 0} {$k < max([llength $a], [llength $b])} {incr k} {
		lappend o [lindex $a $k] [lindex $b $k]
	}
	return $o
}

proc collect {lambda list} {
	set result {}
	foreach item $list {
		lappend result [uplevel apply $lambda $item]
	}
	return $result
}
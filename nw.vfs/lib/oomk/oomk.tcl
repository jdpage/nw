# oomk -- an object-oriented Tcl wrapper around Metakit / Mk4tcl
#
# Example: instead of "mk::view size db.names", we create a $names cmd
# and use "$names size", this is similar to the way Tk widgets work.
#
# This implementation uses Will Duquette's "snit" pure-tcl OO system,
# see http://wiki.tcl.tk/snit and http://www.wjduquette.com/snit/
#
# Written by Jean-Claude Wippler <jcw@equi4.com>, Jan 2003.
# Hold the author harmless and any lawful use is permitted.

package provide oomk 0.3.5
package require snit 0.8
package require Mk4tcl 2.4.9

# wrapper for MK storages (which are also views)
snit::type mkstorage {
  delegate method * to mk
  variable db
  constructor {args} {
    set db db_[namespace tail $self]
    eval [linsert $args 0 mk::file open $db]
    set mk [mkpath $db]
  }
  destructor {
    $mk destroy ;# 2005-08-22 BTS#121 was "close", leaked a snit wrapper
    mk::file close $db
  }
# underlying MK dataset name
  method dbname {} { return $db }
# puts self in a var, with cleanup as unset trace
  method as {vname} {
    upvar 1 $vname v
    set v $self
    trace add variable v unset "$self destroy ;#"
  }
# calls which operate on the dataset
  method commit {} {
    mk::file commit $db
  }
# define or restructure or inspect a top level view (or entire storage)
  method layout {args} {
    if {[llength $args] == 0} {
      set args [linsert $args 0 $db]
    } else {
      lset args 0 $db.[lindex $args 0]
    }
    eval [linsert $args 0 mk::view layout]
  }
# create toplevel view object, restructuring it if needed
  method view {view {fmt ""}} {
    if {$fmt ne ""} { $self layout $view $fmt }
    $self open 0 $view
  }
# create and fill a (flat) view with data
  method define {vname vars {data ""}} {
    upvar 1 $vname v
    [$self view $vname $vars] as v
    set i 0
    foreach x $vars { lappend temps v[incr i] }
    foreach $temps $data {
      set c [list $v append]
      foreach x $vars y $temps { lappend c $x [set $y] }
      eval $c
    }
  }
}

# create snit object (a "snob"?) from a MK path description
proc mkpath {args} {
  _mksnit [eval [linsert $args 0 mk::view open]]
}

# mk commands objects are renamed to "blah.mk", so snit becomes "blah"
proc _mksnit {v} {
  set v [namespace which $v]
  rename $v $v.mk
  mkview $v $v.mk
}

# wrapper for MK views
snit::type mkview {
  delegate method * to mk
  constructor {v} { set mk $v }
  destructor { $mk close }
# underlying MK view name
  method mkname {} { return $mk }
# puts self in a var, with cleanup as unset trace
  method as {vname} {
    upvar 1 $vname v
    set v $self
    trace add variable v unset "$self destroy ;#"
  }
# row operations
  method insert {pos args} {
    if {[llength $args] == 1} { set args [lindex $args 0] }
    eval [linsert $args 0 $self.mk insert $pos]
  }
  method append {args} {
    $self insert end $args
  }
  method delete {args} {
    eval [linsert $args 0 $self.mk delete]
  }
# expand args if needed (i.e. if 1 arg given, "flatten" it)
  foreach x {find search} {
    eval [string map [list #M# $x] {
      method #M# {args} {
	if {[llength $args] == 1} { set args [lindex $args 0] }
	eval [linsert $args 0 $self.mk #M#]
      }
    }]
  }
# unary view ops
  foreach x {blocked clone copy readonly unique} {
    eval [string map [list #M# $x] {
      method #M# {} {
	_mksnit [$self.mk view #M#]
      }
    }]
  }
# binary view ops
  foreach x {concat different intersect map minus pair product union} {
    eval [string map [list #M# $x] {
      method #M# {view} {
	_mksnit [$self.mk view #M# $view.mk]
      }
    }]
  }
# unary varargs view ops
  foreach x {flatten ordered project range rename restrict} {
    eval [string map [list #M# $x] {
      method #M# {args} {
	_mksnit [eval [linsert $args 0 $self.mk view #M#]]
      }
    }]
  }
# 2003-06-11: work around groupby bug in mk4too
  method groupby {subv args} {
    _mksnit [eval [linsert $args 0 $self.mk view groupby $subv:V]]
  }
# 2006-03-01: indexed operation API is slightly different
  method indexed {map args} {
    _mksnit [eval [linsert $args 0 $self.mk view indexed $map.mk]]
  }
# binary varargs view ops
  foreach x {hash join} {
    eval [string map [list #M# $x] {
      method #M# {view args} {
	_mksnit [eval [linsert $args 0 $self.mk view #M# $view.mk]]
      }
    }]
  }
  method select {args} {
    if {[llength $args] == 1} { set args [lindex $args 0] }
    set tmpView [_mksnit [eval [linsert $args 0 $self.mk select]]]
    if {[lsearch -exact $args -sort] >= 0 ||
	[lsearch -exact $args -rsort] >= 0} { return $tmpView }
    set view [$self map $tmpView]
    $tmpView destroy
    return $view
  }
# other ops
  method noop {} { } ;# baseline for timing purposes
# create subview object
  method open {row prop} {
    _mksnit [$self.mk open $row $prop]
  }
# avoid "info" name clash with snit
  method properties {} {
    $self.mk info
  }
# pretty-print contents
  method dump {{prefix ""}} {
    set h [$self.mk info]
    foreach x $h {
      foreach {h t} [split $x :] break
      switch $t I - F - D - B { set a "" } default { set a - }
      lappend wv [string length $h]
      lappend hv $h
      lappend tv $t
      lappend av $a
    }
    set dv {}
    $self.mk loop c {
      set c [eval [linsert $hv 0 $self.mk get $c]]
      set ov {}
      set nv {}
      foreach d $c w $wv t $tv a $av {
        set l [string length $d]
	if {$l > $w} { set w $l }
        lappend ov $d
	lappend nv $w
      }
      set wv $nv
      lappend dv $c
    }
    foreach w $wv a $av {
      lappend sv [string repeat - $w]
      lappend fv "%${a}${w}s"
    }
    set sep $prefix[join $sv "  "]
    set fmt [join $fv "  "]
    puts $prefix[eval [linsert $hv 0 format $fmt]]
    puts $sep
    foreach x $dv {
      puts $prefix[eval [linsert $x 0 format $fmt]]
    }
    puts $sep
  }
# create a cursor to match a row
  method cursor {aname} {
    uplevel 1 [list mkx::acursor $aname $self.mk]
  }
# create a cursor and loop over it
  method loop {aname body} {
    uplevel 1 [list $self cursor $aname]
    upvar $aname aref
    set n [$self size]
    for {set aref(#) 0} {$aref(#) < $n} {incr aref(#)} {
      set c [catch { uplevel 1 $body } r]
      switch -exact -- $c {
        0 {}
	1 { return -errorcode $::errorCode -code error $r }
	3 { return }
	4 {}
	default { return -code $c $r }
      }
    }
  }
}

namespace eval mkx {

  proc _rtracer {view subs a e op} {
    upvar 1 $a aref
    if {$e ne "#"} {
      if {[lsearch -sorted $subs $e] < 0} {
	set aref($e) [$view get $aref(#) $e]
      } else {
	set aref($e) [_mksnit [$view open $aref(#) $e]]
	trace add variable aref($e) unset "$aref($e) destroy ;#"
      }
    }
  }

  proc _wtracer {view a e op} {
    upvar 1 $a aref
    if {$e ne "#"} {
      $view set $aref(#) $e $aref($e)
    }
  }

  proc acursor {aname view} {
    upvar 1 $aname aref
    unset -nocomplain aref
    set aref(#) 0
    set subs {}
    foreach x [$view info] {
      foreach {prop type} [split $x :] break
      if {$type eq "V"} {
        lappend subs $prop
      }
      set aref($prop) ""
    }
    trace add variable aref read \
    	[list [namespace which _rtracer] $view [lsort $subs]]
    trace add variable aref write \
    	[list [namespace which _wtracer] $view]
  }

  proc viewof {aname} {
    upvar 1 $aname aref
    foreach x [trace info variable aref] {
      if {[lindex $x 1 0] eq "::mkx::_rtracer"} {
	return [lindex $x 1 1]
      }
    }
  }
}

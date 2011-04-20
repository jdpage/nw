package provide app-nw-store 1.0

package require sha1
package require struct
package require app-nw-common

load libtclsqlite3.so

namespace eval store {
	sqlite3 db wiki.db
	
	# adds the relevant tables to the db
	proc init {root password} {
		set passhash [::sha1::sha1 $password]
		
		db eval {
			create table users (
				userid		integer	primary key,
				name		text	unique,
				password	text,
				level 		integer);
			create table pages (
				pageid		integer	primary key,
				title		text	unique,
				author		integer,
				content		text,
				edited		integer,
				level		integer,
							foreign key(author) references users(userid));
			create table revisions (
				revid		integer	primary key,
				pageid		integer,
				author		integer,
				diff		text,
				edited		integer, 
							foreign key(author) references users(userid),
							foreign key(pageid) references pages(pageid));
			create table links (
				page		integer,
				ref			integer,
							foreign key(page) references articles(pageid),
							foreign key(ref) references articles(pageid));
			insert into users values(null, $root, $passhash, 0);
		}
	}
}

namespace eval obj {
	proc __getcolumns {table} {
		set columns {}
		set cinfo [store::db eval "pragma table_info($table)"]
		set prk {}
		foreach {cid name type notnull dflt_value pk} $cinfo {
			lappend columns $name
			if {$pk} {set prk $name}
		}
		return [list $prk $columns]
	}
	proc fetch {table id} {
		foreach {prk columns} [__getcolumns] {}
		dict create {*}[zip $columns [store::db eval "select * from $table where $prk='$id'"]]
	}
	proc fabricate {table args} {
		dict create {*}[zip [lindex [__getcolumns] 1] $args]
	}
	proc create {table args} {insert $table [fabricate $table {*}$args]}
	proc quote {i} {
		if {$i eq ""} {
			return NULL
		} elseif {[string is integer $i] || [string is double $i]} {
			return $i
		}
		return '$i'
	}
	proc insert {table obj} {
		foreach {prk columns} [__getcolumns] {}
		dict set obj $prk {}
		set keys [join [dict keys $obj] ,]
		set values [join [collect {{val} {quote $val}} [dict values $obj]] ,]
		store::db eval "insert into $table ($keys) values($values)"
		dict set obj $prk [store::db last_insert_rowid]
		return $obj
	}
	proc update {table obj} {
		set prk [lindex [__getcolumns] 0]
		set pairs [collect {{key val} {return "$key=[quote $val]"}} $obj]select pages title $title]
		store::db eval "update $table set [join $pairs ,] where $prk=[dict get $obj $prk]"
	}
	proc delete {table obj} {
		set prk [lindex [__getcolumns] 0]
		store::db eval "delete from $table where $prk=[dict get $obj $prk]"
	}
	proc select {table args} {
		set out {}
		set orderby ""
		if {"-orderby" in $args} {
			set i [lsearch -exact -- $args "-orderby"]
			set orderby "ORDER BY [lindex $args [expr {$i + 1}]]"
			set args [lreplace $args $i [expr {$i + 1}]]
		}
		set pairs "where [join [collect {{key val} {return "$key=[quote $val]"}} $obj] " and "]"
		store::db eval "select * from $table $pairs $orderby" vals {
			catch {unset vals(*)}
			uplevel [list lappend out [dict create {*}[array get vals]]]
		}
		return $out
	}
}

namespace eval user {
	namespace export *
	namespace ensemble create
	
	proc new {name password level} {obj::create users {} $name [::sha1::sha1 $password] $level}
	proc get {name} {obj::select users name $name}
	
	proc setpassword {user password} {
		dict set user password [::sha1::sha1 $password]
		obj::update users $user
		return $user
	}
	proc authenticate {user password} {expr {[dict get $user password] eq [::sha1::sha1 $password]}}
}

namespace eval page {
	namespace export *
	namespace ensemble create
	
	proc patch {old patch} {
		set old [split $old \n]
		set p [split $patch \n]
		foreach line $p {
			if {$line eq ""} {
				continue
			} elseif {[string index $line 0] eq "d"} {
				set dlines [lrange [split $line] 1 end]
				foreach n [lreverse $dlines] {
					set old [lreplace $old $n $n]
				}
			} else {
				set n [lindex [split $line \t] 0]
				set t [join [lrange [split $line \t] 1 end] \t]
				set old [linsert $old $n $t]
			}
		}
		
		join $old \n
	}
	
	proc get {title {asof now}} {
		set obj [obj::select pages title $title]
		if {$asof ne "now"} {
			set patches [obj::select revisions -orderby {edited desc} pageid [dict get $obj pageid]]
			set body [dict get $obj content]
			foreach patch $patches {
				dict set obj content [patch [dict get $obj content] [dict get $patch diff]]
				dict set obj edited [dict get $patch edited]
				dict set obj author [dict get $patch author]
			}
		}
		return $obj
	}
	proc revise {page new} {
		set author [obj::get users [dict get $new author]]
		if {[dict get $author level] > [dict get $page level]} {
			return [list 1]
		} else {
			set diff [page diff [dict get $page content] <- [dict get $new content]]
			set patch [obj::fabricate revisions {} [dict get $page pageid] [dict get $page author] $diff [dict get $page edited]]
			obj::insert revisions $patch
			obj::update pages $new
		}
	}
	proc diff {a d b} {
		set new [split [body $a] \n]
		set old [split $b \n]
		if {$d eq "->"} {
			set t $new
			set new $old
			set old $t
		}
		
		set lcs [::struct::list longestCommonSubsequence $old $new]
		
		set alines [list]
		set dlines [list]
		
		for {set oldidx 0; set lcsidx 0} {$oldidx < [llength $old]} {incr oldidx} {
			if {$oldidx != [lindex [lindex $lcs 0] $lcsidx]} {
				lappend dlines $oldidx
			} else {
				incr lcsidx
			}
		}
		
		for {set newidx 0; set lcsidx 0} {$newidx < [llength $new]} {incr newidx} {
			if {$newidx != [lindex [lindex $lcs 1] $lcsidx]} {
				lappend alines $newidx
			} else {
				incr lcsidx
			}
		}
		
		set out "d $dlines\n"
		foreach n $alines {
			append out "$n\t[lindex $new $n]\n"
		}
		return $out
	}
}

namespace eval link {
	namespace export *
	namespace ensemble create
	
	proc isinternal {href} {
		expr {![regexp {.*(/|\?).*} $href] && [string index $href 0] ne "_" && \
			![regexp {mailto:.*} $href] && ![regexp {.*@.+} $href]}
	}
	proc clear {page} {
		set uid [page id $page]
		store::db eval {DELETE FROM links WHERE page=$uid}
	}
	proc add {page to} {
		set f [page id $page]
		set t [page id $to]
		if {[llength [store::db eval {SELECT page FROM links WHERE page=$f AND ref=$t}]] == 0} {
			store::db eval {INSERT INTO links VALUES($f, $t)}
		}
	}
	proc refs {page} {
		set uid [page id $page]
		store::db eval {SELECT page FROM links WHERE ref=$uid}
	}
	proc refresh {page} {
		set txt [page body $page]
		clear $page
		set links [regexp -all -inline -- {\[\[(?!\[)(.*?)(?: .*?)?\]\]} [lindex $txt 2]] ; # ] because vim.
		foreach {slot url} $links {
			if {[isinternal $url]} {
				add $page [page get $url]
			}
		}
	}
}

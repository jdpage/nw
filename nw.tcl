#!/usr/bin/env tclsh8.5

if {[catch {

package require sqlite3
package require ncgi
package require sha1

sqlite3 db "/home/protected/nw/wiki.db"

namespace eval element { # {{{
	proc entry {txt_label txt_name {txt_default ""}} { return "$txt_label: <input type='text' name='$txt_name' value='$txt_default' /><br />" }
	proc password {txt_label txt_name} {return "$txt_label: <input type='password' name='$txt_name' /><br />"}
	proc submit {txt_label} {return "<input type='submit' value='$txt_label' />"}
	proc embed {txt_name ff_value} {return "<input type='hidden' name='$txt_name' value='$ff_value' />"}
	proc errmsg {txt_mesg} {return "<span class='error'>$txt_mesg</span><br />"}
	proc link {href {txt_text ""}} {
		if {[regexp {.*(/|\?).*} $href] || [string index $href 0] eq "_"} {
		} elseif {[regexp {mailto:.*} $href]} {} elseif {[regexp {.*@.+} $href]} {
			set href "mailto:$href"
		} else {
			if {![exists $href]} {set href "$href' style='color:red"}
		}
		set l "<a href='$href'>"; if {$text ne ""} {append l $txt_text} else {append l $href}; return "$l</a>"
	}
	proc title {ut_page {txt_extra ""} {f_linkit 0}} {
		if {$f_linkit == 1} {
			return "<h1>$txt_extra [link $ut_page [niceify $ut_page]]</h1>"
		} elseif {$f_linkit == 2} {
			return "<h1>$txt_extra [link $ut_page?mode=refs [niceify $ut_page]]</h1>"
		}
		return "<h1>$txt_extra [niceify $ut_page]</h1>"
	}
	namespace export *
	namespace ensemble create
} # }}}

namespace eval page { # {{{
} # }}}

namespace eval link { # {{{
	proc clear {::db eval {DELETE FROM links WHERE page=$id}}
	proc add {from to} {
		# Check that this is 
		if {[llength [::db eval {SELECT page FROM links WHERE page=$from AND ref=$to}]] == 0} {
			::db eval {INSERT INTO links VALUES($from, $to)}
		}
	}
	proc isinternal {href} {
		expr {![regexp {.*(/|\?).*} $href] && [string index $href 0] ne "_" && \
			![regexp {mailto:.*} $href] && ![regexp {.*@.+} $href]}
	}
	proc find {to} {::db eval {SELECT page FROM links WHERE ref=$to}}
	namespace export *
	namespace ensemble create
} # }}}

namespace eval user { # {{{
} # }}}

# datatypes: id, tt = text title, ut = url title, txt = text string, f = flag, ff = freeform

proc footer {title {author ""} {edited ""} {meta 1}} { # {{{
	set s "<hr /><p><em>"
	if {$edited ne ""} {append s "Last edited [fuzz [ago $edited]] ago"}
	if {$author ne ""} {append s " by [link $author]"}
	if {$meta} {append s ", [link $title?mode=edit Edit], [link $title?mode=old History] "}
	append s "([link Main], [link _toc {List all pages}])</em></p>"
} # }}}

# time functions {{{
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
	} elseif {$dtime < 31557600} {
		set t [expr {$t/2629800}]
		return "$t month[s $t]"
	} else {
		set t [expr {$t/31557600}]
		return "$t year[s $t]"
	}
} # }}}

proc reflist {to} { # {{{
	set document "[header $to {References to} 1]<ul>"
	set data [db eval {SELECT page FROM links WHERE ref=$to}]
	if {[llength $data] == 0} {
		append document "<li>No references found</li>"
	} else {
		foreach ref $data {
			append document "<li>[link $ref]</li>"
		}
	}
	append document "</ul>[footer $to \"\" \"\" 1 0]"
} # }}}

proc addentry {title author text} { # {{{
	if {[string index $title 0] eq "_"} { return }
	set time [clock seconds]
	db eval {INSERT INTO articles VALUES($title,$author,$text,$time)}
	clearlinks $title
	set links [regexp -all -inline -- {\[\[(?!\[)(.*?)(?: .*?)?\]\]} $text] ; # ]
	foreach {slot url} $links {
		if {[isinternal $url]} {
			addlink $title $url
		}
	}
} # }}}

proc relink {title} { # {{{
	set e [fetchentry $title]
	if {$e != 0} {
		clearlinks $title
		set links [regexp -all -inline -- {\[\[(?!\[)(.*?)(?: .*?)?\]\]} [lindex $e 2]] ; # ]
		foreach {slot url} $links {
			if {[isinternal $url]} {
				addlink $title $url
			}
		}
	}
} # }}}

proc versionlist {title} { # {{{
	set data [db eval {select * from articles where title=$title order by edited desc}]
	if {[llength $data] == 0} { return 0 }
	set document "[header $title {History of} 1]<ul>"
	foreach {t author text edited} $data {
		append document "<li>[link $title?mode=old&time=$edited [fuzz [ago $edited]]\ ago] by [link $author]</li>"
	}
	append document "</ul>[footer $title]"
} # }}}

proc toc {} { # {{{
	set data [lsort -dictionary -unique [db eval {select title from articles}]]
	set document "[header Table_of_Contents]<ul>"
	foreach title $data { append document "<li>[link $title]</li>" }
	append document "</ul>[footer Table_of_Contents]"
} # }}}

proc users {} { # {{{
	set data [lsort -dictionary -unique [db eval {select name from users}]]
	set document "[header User_List]<ul>"
	foreach name $data {append document "<li>[link $name]</li>"}
	append document "</ul>[footer User_List]"
} # }}}

proc exists {title} {expr {[llength [db eval {select title from articles where title=$title}]] > 0}}

proc fetchentry {title {posted newest}} { # {{{
	set data [db eval {select * from articles where title=$title order by edited desc}]
	if {[llength $data] == 0} {
		return 0
	}
	if {$posted eq "newest"} {
		set title [lindex $data 0]
		set author [lindex $data 1]
		set text [lindex $data 2]
		set edited [lindex $data 3]
	} else {
		foreach {title author text edited} $data {
			if {$posted >= $edited} {break}
		}
	}
	
	return [list $title $author $text $edited]
} # }}}

proc auth {name pass} { # {{{
	set d [db eval {select password from users where name=$name}]
	expr {[llength $d] > 0 && [lindex $d 0] eq [::sha1::sha1 $pass]}
} # }}}

proc createuser {} { # {{{
	set badname 0
	set nomatch 0
	set submit [::ncgi::value submit]
	set username [::ncgi::value username]
	set password [::ncgi::value password]
	set confirm [::ncgi::value password]
	if {$submit eq "true"} {
		if {$username eq "" || [userexists $username]} {
			set badname 1
		} elseif {$password ne $confirm} {
			set nomatch 1
		} else {
			set hash [::sha1::sha1 $password]
			db eval {INSERT INTO users VALUES($username,$hash,2)}
			return "[header Success][link Main {Return to Main}][footer Success]"
		}
	}
	set document "[header Create_User]
<form action='_createuser' method='POST'>
[if {$badname} {errmsg {Invalid username (may already exist)}}]
[entry Username username $username]
[if {$nomatch} {errmsg {Passwords do not match}}]
[password Password password]
[password {Confirm password} confirm]
[embed submit true]
[submit Create]
"
} # }}}

proc userexists {name} {expr {[llength [db eval {select name from users where name=$name}]] > 0}}

proc editpage {title} { # {{{
	if {[string index $title 0] eq "_"} { return }
	if {[::ncgi::value content] ne ""} {
		set data [::ncgi::value content]
	} elseif {[set entry [fetchentry $title]] != 0} {
		set data [lindex $entry 2]
	} else {
		set data ""
	}
	
	set document "[header $title Editing]
<form action=\"$title\" method=\"POST\">
<textarea rows='50' cols='80' name='content'>$data</textarea>
<br /><br />
[entry Username author]
[password Password password]
[embed mode save]
[submit Save]
</form>
[footer $title]"
}

proc renderentry {e} {
	set title [lindex $e 0]
	set author [lindex $e 1]
	set rawtext [split [lindex $e 2] \n]
	set edited [lindex $e 3]
	
	set out {}
	set next ""
	
	foreach line $rawtext {
		if {[regexp {^ {4,}.*$} $line]} {
			if {$next ne "</code></pre>"} { lappend out "$next<pre><code>" }
			lappend out [string map {"<" "&lt;" ">" "&gt;"} $line]
			set next "</code></pre>"
			continue
		}
		
		set escaped [lreverse [regexp -all -inline -indices -- {\\.} $line]]
		foreach escape $escaped {
			set char [string index $line [lindex $escape 1]]
			set escchar "&#[scan $char %c];"
			set line [string replace $line [lindex $escape 0] [lindex $escape 1] $escchar]
		}
		
		if {[regexp {(\={2,6})(.*?)\1} $line match level text]} {
			set ln [string length $level]
			set line "<h$ln>$text</h$ln>"
			set next ""
		} elseif {[regexp {^# (.*)$} $line match text]} {
			if {$next ne "</ol>"} { lappend out "$next<ol>" }
			set line "<li>$text</li>"
			set next "</ol>"
		} elseif {[regexp {^\* (.*)$} $line match text]} {
			if {$next ne "</ul>"} { lappend out "$next<ul>" }
			set line "<li>$text</li>"
			set next "</ul>"
		} elseif {[regexp {^[[:space:]]*$} $line match]} {
			lappend out $next
			set next ""
		} else {
			if {$next ne "</p>"} { lappend out "$next<p>" }
			set next "</p>"
		}
		set links [lreverse [regexp -all -inline -indices -- {\[\[(?!\[)(.*?)(?: (.*?))?\]\]} $line]] ; # ]
		foreach {text url slot} $links {
			set link ""
			set texturl [string range $line [lindex $url 0] [lindex $url 1]]
			if {[lindex $text 0] == -1} {
				set link [link $texturl [niceify $texturl]]
			} else {
				set link [link $texturl [string range $line [lindex $text 0] [lindex $text 1]]]
			}
			set line [string replace $line [lindex $slot 0] [lindex $slot 1] $link]
		}
		
		regsub -all -- {\{\{(.*?) (.*?)\}\}} $line {<img src="\1" alt="\2" title="\2" />} line
		regsub -all -- {\m_(.*?[^\\])_\M} $line {<em>\1</em>} line
		regsub -all -- {(?!\M)\*(.*?[^\\])\*(?!\m)} $line {<strong>\1</strong>} line
		regsub -all -- {\`\`(.*?)\'\'} $line {\&ldquo;\1\&rdquo;} line
		regsub -all -- {(?!\M)@(.*?)@(?!\m)} $line {<code>\1</code>} line
		lappend out $line
	}
	lappend out $next
	set fulltext [join $out ""]
	set document "[header $title "" 2]$fulltext[footer $title $author $edited 1]"
	return $document
}

proc fourohfour {title} {
	set document "[header $title {Cannot find}]<p>You can [link $title?mode=edit {create this page}]</p>[footer $title]"
}

proc niceify {title} { string map {"_" " "} $title }

if {![info exists env(PATH_INFO)]} {set env(PATH_INFO) "/Main"}

::ncgi::header
::ncgi::parse

set page [string range $env(PATH_INFO) 1 end]
if {$page eq ""} { set page Main }

if {[string index $page 0] eq "_"} {
	switch $page {
		_toc {puts [toc]}
		_users {puts [users]}
		_createuser {puts [createuser]}
		_links {
			foreach {f t} [db eval {select * from links}] {
				puts "$f -> $t<br />"
			}
		}
		_relink {
			foreach t [lsort -dictionary -unique [db eval {select title from articles}]] {
				puts "Relinking $t<br />"
				relink $t
			}
		}
		default {puts "Unknown special page"}
	}
} else {
	switch [::ncgi::value mode] {
		edit { puts [editpage $page] }
		refs { puts [reflist $page] }
		save {
			if {[auth [::ncgi::value author] [::ncgi::value password]]} {
				addentry $page [::ncgi::value author] [::ncgi::value content]
				puts [renderentry [fetchentry $page]]
			} else {
				puts [editpage $page]
			}
		}
		old {
			set time [::ncgi::value time]
			if {$time eq ""} {
				set e [versionlist $page]
				if {$e == 0} {set e [fourohfour $page]}
				puts $e
			} else {
				set e [fetchentry $page $time]
				if {$e == 0} {
					puts [fourohfour $page]
				} else {
					lset e 2 "<p><em>This is version of the article from sometime in the past. [link $page {The newest version}] may have substantial differences.</em></p>[lindex $e 2]"
					puts [renderentry $e]
				}
			}
		}
		default {
			if {[set e [fetchentry $page]] != 0} {
				puts [renderentry $e]
			} else {
				puts [fourohfour $page]
			}
		}
	}
}

} stuff]} {

	::ncgi::header text/plain
	puts "<pre>"
	puts $stuff
	puts $errorInfo
	puts "</pre>"
}

#!/usr/bin/env tclsh8.5

if {[catch {

package require sqlite3
#load /usr/local/lib/sqlite3/libtclsqlite3.so sqlite
package require ncgi

sqlite3 db "/home/protected/nw/wiki.db"

proc setup {} {
	db eval {create table articles (title text, author text, content text, edited integer)}
}

proc header {title {extra ""} {linkit 0}} {
	set head "<!DOCTYPE html><html><head><title>$extra [niceify $title]</title></head><body>"
	if {$linkit} {
		append head "<h1>$extra <a href='$title'>[niceify $title]</a></h1>"
	} else {
		append head "<h1>$extra [niceify $title]</h1>"
	}
	return $head
}

proc footer {title {author ""} {edited ""} {links 0}} {
	if {$links} {
		set s "<hr /><p><em>"
		if {$edited ne ""} {append s "Last edited at [clock format $edited] "}
		if {$author ne ""} {append s "by <a href=\"$author\">$author</a> "}
		append s "\[<a href='$title?mode=edit'>Edit</a> - <a href='$title?mode=old'>History</a>\]</em></p></body></html>"
	} else {
		return "</body></html>"
	}
}

proc addentry {title author text} {
	set time [clock seconds]
	db eval {INSERT INTO articles VALUES($title,$author,$text,$time)}
}

proc versionlist {title} {
	set data [db eval {select * from articles where title=$title order by edited desc}]
	if {[llength $data] == 0} {
		return 0
	}
	
	set document "[header $title {History of} 1]<ul>"
	
	foreach {t author text edited} $data {
		append document "<li><a href='$title?mode=old&time=$edited'>[clock format $edited]</a> by <a href='$author'>$author</a></li>"
	}
	
	append document "</ul>[footer $title]"
	return $document
}

proc toc {} {
	set data [lsort -dictionary -unique [db eval {select title from articles}]]
	set document "[header Table_of_Contents]<ul>"

	foreach title $data {
		append document "<li><a href='$title'>$title</a></li>"
	}
	
	append document "</ul>[footer Table_of_Contents]"
	return $document
}

proc fetchentry {title {posted newest}} {
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
			if {$posted >= $edited} {
				break
			}
		}
	}
	
	return [list $title $author $text $edited]
}

proc editpage {title} {
	set entry [fetchentry $title]
	if {$entry != 0} {
		set data [lindex $entry 2]
	} else {
		set data ""
	}
	
	set document "[header $title Editing]
<form action=\"$title\" method=\"POST\">
<textarea rows='50' cols='80' name='content'>$data</textarea>
<br /><br />
Username: <input type='text' name='author' />
<input type='hidden' name='mode' value='save' />
<input type='submit' value='Save' />
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
			if {$next ne "</pre>"} { lappend out "$next<pre>" }
			lappend out $line
			set next "</pre>"
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
		set links [lreverse [regexp -all -inline -indices -- {\[\[(?!\[)(.*?)(?: (.*?))?\]\]} $line]]
		foreach {text url slot} $links {
			set link ""
			set texturl [string range $line [lindex $url 0] [lindex $url 1]]
			if {[lindex $text 0] == -1} {
				set link "<a href='$texturl'>[niceify $texturl]</a>"
			} else {
				set texttext [string range $line [lindex $text 0] [lindex $text 1]]
				set link "<a href='$texturl'>$texttext</a>"
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
	set document "[header $title]$fulltext[footer $title $author $edited 1]"
	return $document
}

proc fourohfour {title} {
	set document "[header $title {Cannot find}]<p>You can <a href='$title?mode=edit'>create this page</a></p>[footer $title]"
}

proc niceify {title} { string map {"_" " "} $title }

if {0} {
if {$env(PATH_INFO) eq "/_setup"} {
	setup
	::ncgi::header text/plain
	puts "Done"
	exit
}
}

if {![info exists env(PATH_INFO)]} {set env(PATH_INFO) "/Main"}

::ncgi::header
::ncgi::parse

set p -1
while {[string index $env(PATH_INFO) $p] eq "/"} { incr p -1 }
set page [string range $env(PATH_INFO) 1 end]
if {$page eq ""} { set page Main }
set mode [::ncgi::value mode]

if {$page eq "_toc"} {
	puts [toc]
} elseif {$mode eq "edit"} {
	puts [editpage $page]
} elseif {$mode eq "save"} {
	set author [::ncgi::value author]
	set content [::ncgi::value content]
	addentry $page $author $content
	puts [renderentry [fetchentry $page]]
} elseif {$mode eq "old"} {
	set time [::ncgi::value time]
	if {$time eq ""} {
		set e [versionlist $page]
		if {$e == 0} {
			puts [fourohfour $page]
		} else {
			puts $e
		}
	} else {
		set e [fetchentry $page $time]
		if {$e == 0} {
			puts [fourohfour $page]
		} else {
			puts "<p><em>This is version of the article from sometime in the past. <a href='$page'>The newest version</a> may have substantial differences.</em></p>"
			puts [renderentry $e]
		}
	}
} else {
	set e [fetchentry $page]
	if {$e == 0} {
		puts [fourohfour $page]
	} else {
		puts [renderentry $e]
	}
}

} stuff]} {

	::ncgi::header text/plain
	puts $stuff
	puts $errorInfo
}

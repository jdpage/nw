#!/usr/bin/env tclsh8.5

if {[catch {

package require sqlite3
#load /usr/local/lib/sqlite3/libtclsqlite3.so sqlite
package require ncgi

sqlite3 db "wiki.db"

proc setup {} {
	db eval {create table articles (title text, author text, content text, edited integer)}
}

proc addentry {title author text} {
	set title [uglify $title]
	set time [clock seconds]
	db eval {INSERT INTO articles VALUES($title,$author,$text,$time)}
}

proc versionlist {title} {
	set data [db eval {select * from articles where title=$title order by edited desc}]
	if {[llength $data] == 0} {
		return 0
	}
	
	set document "<!DOCTYPE html>
<html>
<head><title>History of $title</title></head>
<body>
<h1>History of <a href='$title'>$title</a></h1><ul>"
	
	foreach {t author text edited} $data {
		append document "<li><a href='$title?mode=old&time=$edited'>[clock format $edited]</a> by <a href='$author'>$author</a></li>"
	}
	
	append document "</ul></body></html>"
	return $document
}

proc toc {} {
	set data [lsort -dictionary -unique [db eval {select title from articles}]]
	set document "<!DOCTYPE html>
<html>
<head><title>Table of Contents</title></head>
<body>
<h1>Table of Contents</h1><ul>"

	foreach title $data {
		append document "<li><a href='$title'>$title</a></li>"
	}
	
	append document "</ul></body></html>"
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
	
	set document "<!DOCTYPE html>
<html>
<head><title>Editing $title</title></head>
<body>
<h1>Editing $title</h1>
<form action=\"$title\" method=\"POST\">
<textarea rows='50' cols='80' name='content'>$data</textarea>
<br /><br />
Username: <input type='text' name='author' />
<input type='hidden' name='mode' value='save' />
<input type='submit' value='Save' />
</form>
</body>
</html>"
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
			if {$next ne "</pre>"} {
				lappend out $next
				lappend out "<pre>"
			}
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
			if {$next ne "</ol>"} {
				lappend out $next
				lappend out "<ol>"
			}
			set line "<li>$text</li>"
			set next "</ol>"
		} elseif {[regexp {^\* (.*)$} $line match text]} {
			if {$next ne "</ul>"} {
				lappend out $next
				lappend out "<ul>"
			}
			set line "<li>$text</li>"
			set next "</ul>"
		} elseif {[regexp {^[[:space:]]*$} $line match]} {
			lappend out $next
			set next ""
		} else {
			if {$next ne "</p>"} {
				lappend out $next
				lappend out "<p>"
			}
			set next "</p>"
		}
		set links [lreverse [regexp -all -inline -indices -- {\[\[(?!\[)(.*?)(?: (.*?))?\]\]} $line]]
		foreach {text url slot} $links {
			set link ""
			set texturl [string range $line [lindex $url 0] [lindex $url 1]]
			if {[lindex $text 0] == -1} {
				set link "<a href='$texturl'>$texturl</a>"
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
	
	set document "<!DOCTYPE html>
	<html>
	<head><title>[niceify $title]</title></head>
	<body>
	<h1>[niceify $title]</h1>
	<p></p>
	$fulltext
	<hr />
	<p><em>Last edited by <a href=\"$author\">$author</a> at [clock format $edited] - <a href='$title?mode=edit'>Edit</a> - <a href='$title?mode=old'>History</a></em></p>
	</body>
	</html>"
	
	return $document
}

proc fourohfour {title} {
	set document "<!DOCTYPE html>
	<html>
	<head><title>Cannot find [niceify $title]</title></head>
	<body>
	<h1>Cannot find [niceify $title]</h1>
	<p>You can <a href='$title?mode=edit'>create this page</a></p>
	</body>
	</html>"
}

proc uglify {title} {
	set str ""
	foreach i [split $title ""] {
		if {[string is alnum $i]} {
			append str $i
		} elseif {$i eq " " || $i eq "_"} {
			append str "_"
		} elseif {$i eq "-"} {
			append str $i
		}
	}
	return $str
}

proc niceify {title} {
	string map {"_" " "} $title
}

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
while {[string index $env(PATH_INFO) $p] eq "/"} {
	incr p -1
}

set page [string range $env(PATH_INFO) 1 end]

if {$page eq ""} {
	set page Main
}

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
}

package provide app-nw-store 1.0

package require app-nw-common
package require app-nw-store

proc html {tag args} {
	if {$tag ne "_"} {
		set out "<$tag"
		foreach {i j} $args {
			if {[string index [set content $i] 0] ne "-" ||
			  ($i eq "--" && [set content $j] ne "--")} {
				return "$out>[join $content]</$tag>"
			}
			append out " [string range $i 1 end]='$j'"
		}
		append out " />"
	} else {
		foreach {href text} $args {
			if {[regexp {.*(/|\?).*} $href] || [string index $href 0] eq "_"} {
			} elseif {[regexp {mailto:.*} $href]} {} elseif {[regexp {.*@.+} $href]} {
				set href "mailto:$href"
			} else {
				if {![exists $href]} {set href "$href' style='color:red"}
			}
			return [html a -href $href -- [expr {$text ne "" ? $text : $href}]]
		}
	}
}

namespace eval render {
	namespace export *
	namespace ensemble create
	
	proc tohtml {text} {
		set rawtext [split $text \n]
		
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
					set link [html link $texturl [niceify $texturl]]
				} else {
					set link [html link $texturl [string range $line [lindex $text 0] [lindex $text 1]]]
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
		join $out ""
	}
	proc template {templated paged} {
		set tplt [dict get $template body]
		set o [string map -nocase [list \
			"<nw:title />"	[dict get $page title] \
			"<nw:url />"	[dict get $page title] \
			"<nw:body />"	[dict get $page body] \
			"<nw:edited />"	[timestamp pretty [dict get $page edited]] \
			"<nw:author />"	[html link [dict get $page author]] \
		] $tplt]
		return $o
	}
}

namespace eval special {
	namespace export *
	namespace ensemble create
	
	proc template_main {} {page todict [page get template_main]}
	proc template_special {} {page todict [page get template_special]}
	
	proc toc {} {
		set titles [page getall title]
		set text [html ul [collect {{title} {html li [html link $title]}} $titles]]
		set paged [dict create \
			title  "Table of Contents" \
			body   $text \
			author "" \
			edited [timestamp now]]
		render template [template_special] $paged
	}
	
	proc versions {title} {
		set versions [page getversions $title]
		set text "<ul>"
		foreach page $versions {
			set edited [page edited $page]
			set author [user name [page author $page]]
			append text "<li>[link $title?mode=old&time=$edited [fuzz [ago $edited]]\ ago] by [link $author]</li>"
		}
		append text "</ul>"
		set paged [dict create \
			title  "History of $title" \
			body   $text \
			author "" \
			edited [timestamp now]]
		render template [template_special] $paged
	}
	
	proc users {title} {
		set users [users getall name]
		set text "<ul>"
		foreach name $data {append text "<li>"}
	}
}
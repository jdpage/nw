#!/usr/bin/env tclsh8.5

package require sqlite3
package require sha1

set dbname [lindex $argv 0]

sqlite3 db $dbname

# get data

puts -nonewline "Input admin username (use letters, numbers, and underscores only; any other characters will be ignored) > "
flush stdout
gets stdin username

puts -nonewline "Input admin password > "
flush stdout
gets stdin password
set passhash [::sha1::sha1 $password]

# Create user, page, and link tables

# Contains users 
db eval {
	CREATE TABLE users (
		userid INTEGER PRIMARY KEY,
		name TEXT UNIQUE,
		password TEXT, -- this is a sha1 passhash
		permissions INTEGER
	);
}

# The core of the wiki. Everything is a page - even user preferences.
# types: wikimarkup = 0, plain text = 1, template = 2, script = 3

db eval {
	CREATE TABLE pages (
		pageid INTEGER PRIMARY KEY,
		title TEXT UNIQUE,
		author INTEGER,
		content TEXT,
		edited INTEGER,
		type INTEGER,
		permissions INTEGER,
		FOREIGN KEY(author) REFERENCES users(userid)
	);
}

# Table of links
db eval {
	CREATE TABLE links (
		page INTEGER,
		ref INTEGER,
		FOREIGN KEY(page) REFERENCES articles(pageid),
		FOREIGN KEY(ref) REFERENCES articles(pageid)
	);
}

db eval {INSERT INTO users VALUES(NULL, $username, $passhash, 99);}

set pagetemplate {
<!DOCTYPE html>
<html>
	<head>
		<title>$title</title>
		<link rel='stylesheet' href='stylesheet_main' type='text/css' />
	</head>
	<body>
		$body
		<hr />
		<p><em>
			[if {$t_edited ne ""} {be "Last edited [fuzz [ago $t_edited]] ago"}]
			[if {$txt_author ne ""} {be "by [link $txt_author]"}]
			[if {$f_meta} {be ", [link $ut_page?mode=edit Edit], [link $ut_page?mode=old History] "}]
			([link Main], [link _toc {List all pages}])
		</em></p>
	</body>
</html>
}

set stylesheet {
	/* Insert styles here */
	
	.error {
		color: red; }
}

set reflist {
	set document "[header $to {References to} 1]<ul>"
	set data [link find $to]
	if {[llength $data] == 0} {
		append document "<li>No references found</li>"
	} else {
		foreach ref $data {
			append document "<li>[link $ref]</li>"
		}
	}
	append document "</ul>[footer $to "" "" 1 0]"
}

set edited [clock seconds]

db eval {INSERT INTO pages VALUES(NULL, `template_main`, $username, $pagetemplate, $edited, 2, 9)}
db eval {INSERT INTO pages VALUES(NULL, `stylesheet_main`, $username, $stylesheet, $edited, 1, 9)}

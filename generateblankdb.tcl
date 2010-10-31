#!/usr/bin/env tclsh8.5

package require sqlite3
package require sha1

set dbname [lindex $argv 0]

sqlite3 db $dbname

# get data

puts -nonewline "Input admin username (use letters, numbers, and underscores only; any other characters will be ignored) > "
gets stdin username

puts -nonewline "Input admin password > "
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
db eval {
	CREATE TABLE pages (
		pageid INTEGER PRIMARY KEY,
		title TEXT UNIQUE,
		author INTEGER,
		content TEXT,
		edited INTEGER,
		type TEXT,
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
#!/usr/bin/env ruby

require "sqlite3"
require "sha1"

dbname = $*[0]

db = SQLite3::Database.new(dbname)

# get data

print "Input admin username (use letters, numbers, and underscores only; any \
       other characters will be ignored) > "
username = $stdin.gets
print "Input admin password > "
passhash = SHA1.hexdigest( $stdin.gets )

db.execute(%{
	CREATE TABLE users (
		userid INTEGER PRIMARY KEY,
		name TEXT UNIQUE,
		password TEXT, -- this is a sha1 passhash
		permissions INTEGER
	)
})

# the core of the wiki. Everything is a page - even user preferences.
# types: wikimarkup = 0, plaintext = 1, template = 2, script = 3

db.execute(%{
	CREATE TABLE pages (
		pageid INTEGER PRIMARY KEY,
		title TEXT UNIQUE,
		author INTEGER,
		content TEXT,
		edited TEXT,
		type INTEGER,
		permissions INTEGER,
		FOREIGN KEY(author) REFERENCES users(userid)
	);
})

# Table of links
db.execute(%{
	CREATE TABLE links (
		page INTEGER,
		ref INTEGER,
		FOREIGN KEY(page) REFERENCES articles(pageid),
		FOREIGN KEY(ref) REFERENCES articles(pageid)
	);
})

db.execute(%{INSERT INTO users VALUES(NULL, ?, ?, 99);}, username, passhash)

pagetemplate = '
<!DOCTYPE html>
<html>
	<head>
		<title>#{title}</title>
		<link rel="stylesheet" href="stylesheet_main" type="text/css" />
	</head>
	<body>
		#{body}
		<hr />
		<p><em>
			#{"Last edited #{fuzz ago t_edited} ago" if t_edited}
			#{"by #{link txt_author}" if txt_author}
			#{", #{link ut_page + "?mode=edit" "Edit"},
			     #{link ut_page + "?mode=old" "History"} " if f_meta}
			(#{link "Main"}, #{link "_toc" "List all pages"})
		</em></p>
	</body>
</html>		
'

stylesheet = '
	/* insert styles here */

	.error {
		color: red; }
'

reflist = '
	document = header(to, "References to", true) + "<ul>"
	data = link.find to
	if data.length == 0
		document << "<li>No references found</li>"
	else
		data.each do |ref|
			document << "<li>#{link ref}</li>"
		end
	end
	document << "</ul>#{footer to, "", "", true, false}"
'

edited = Time.now.to_i

db.execute(%{INSERT INTO pages VALUES(NULL, 'template_main', ?, ?, ?, 2, 9);}, username, pagetemplate, edited);
db.execute(%{INSERT INTO pages VALUES(NULL, 'stylesheet_main', ?, ?, ?, 1, 9);}, username, stylesheet, edited);

#!/usr/bin/env ruby

require "sqlite3"
require "sha1"
require "cgi"

# edit this to point to your DB
$db = SQLite3::Database.new("/home/protected/nw/wiki.db");

module Element
	def entry(label, name, val = "")
		"%s: <input type='text' name='%s' value='%s' /><br />" % [label, name, val]
	end
	def password(label, name)
		"%s: <input type='password' name='%s' /><br />" % [label, name]
	end
	def submit(label); "<input type='submit' value='%s' />" % label; end
	def embed(name, val); "<input type='hidden' name='%s' value='%s' />" % [name, val]; end
	def err_mesg(mesg); "<span class='error'>%s</span><br />" % mesg; end
	def link(href, text = nil)
		phref = href.dup
		unless phref.include? "/" or phref.include? "?" or phref[0].to_c == "_"
			phref = "mailto:" + phref if phref.include? "@" unless phref =~ /^mailto:/
			phref += "' class='redlink" unless phref =~ /^mailto:/ or Page.exists phref
		end
		l = "<a href='%s'>" % phref
		if text; l << text; else; l << href; end;
		l << "</a>"
	end
	def title(page, extra, linkmode)
		if linkmode == :plain
			"<h1>%s #{link page, Link.niceify page}</h1>" % extra
		elsif linkmode == :refs
			"<h1>%s #{link page+".refs", Link.niceify page}</h1>" % extra
		else
			"<h1>%s #{Link.niceify page}</h1>" % extra
		end
	end
end

module Page
end

module Link
	def clear(id); $db.execute("DELETE FROM links WHERE page=?", id); end
	def add(from, to)
		$db.execute "INSERT INTO links VALUES(?, ?)", from, to if \
		  $db.get_first_value "SELECT count(*) FROM links WHERE page=? AND ref=?", \
		  from, to.to_i == 0
	end
	def internal?(href)
		!(href.include? "/" or href.include? "?" or href ~= /^mailto:/ or href.include? "@")
	end
	def find(to)
		$db.execute("SELECT page FROM links WHERE ref=?", to) do |row|
			yield row[0]
		end
	end
end

module User
end



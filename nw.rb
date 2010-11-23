#!/usr/bin/env ruby

require "sqlite3"
require "sha1"
require "cgi"

module Element
	def self.entry(label, name, val = "")
		"%s: <input type='text' name='%s' value='%s' /><br />" % [label, name, val]
	end
	def self.password(label, name)
		"%s: <input type='password' name='%s' /><br />" % [label, name]
	end
	def self.submit(label); "<input type='submit' value='%s' />" % label; end
	def self.embed(name, val); "<input type='hidden' name='%s' value='%s' />" % [name, val]; end
	def self.err_mesg(mesg); "<span class='error'>%s</span><br />" % mesg; end
	def self.link(href, text = nil)
		phref = href.dup
		unless phref.include? "/" or phref.include? "?" or phref[0].to_c == "_"
			phref = "mailto:" + phref if phref.include? "@" unless phref =~ /^mailto:/
			phref += "' class='redlink" unless phref =~ /^mailto:/ or Page.exists phref
		end
		l = "<a href='%s'>" % phref
		if text; l << text; else; l << href; end;
		l << "</a>"
	end
	def self.title(page, extra, linkmode)
		if linkmode == :plain
			"<h1>%s #{link page, Links.niceify(page)}</h1>" % extra
		elsif linkmode == :refs
			"<h1>%s #{link page+".refs", Links.niceify(page)}</h1>" % extra
		else
			"<h1>%s #{Links.niceify(page)}</h1>" % extra
		end
	end
end

class Table
	def self.create(db, table, cols, fkeys)
		db.execute(%{CREATE TABLE #{table} (#{
			colsql = cols.collect {|col| "#{col.keys[0]} #{col[col.keys[0]]}"}
			fksql = fkeys.collect {|l,f| "FOREIGN KEY(#{l}) REFERENCES #{f}"}
			(colsql + fksql).join(", ")
		})})
		new(db, table)
	end
	def initialize(db, table)
		@db = db
		@table = table
		@columns = @db.execute2("SELECT * FROM #{@table} WHERE 0")[0]
		@columns.shift # get rid of id
	end
	def [](id)
		Row.new( id, @db, @table )
	end
	def search_by(column, value)
		id = @db.get_first_value("SELECT id FROM #{@table} WHERE #{column}=?", value)
		return nil unless id
		Row.new(id, @db, @table)
	end
	def has?(id); @db.get_first_value("SELECT count(*) FROM #{@table} WHERE id=?", id).to_i > 0; end
	def size(); @db.get_first_value("SELECT count(*) FROM #{@table}"); end
	def each()
		ids = @db.execute("SELECT id FROM #{@table}")
		ids.each do |id|
			yield Row.new(id[0], @db, @table)
		end
	end
	def add(row)
		@db.execute("INSERT INTO #{@table} VALUES(NULL, #{ @columns.collect { |col| row[col] } .join(", ") })")
		@db.get_first_value("SELECT id FROM #{@table} WHERE #{ @columns.collect { |col| "#{col}=#{row[col]}" } .join(", ") }")
	end
	def drop(id)
		@db.execute("DELETE FROM #{@table} WHERE id=?", id)
	end
end

class Row
	def initialize( id, db, table )
		@id = id
		@db = db
		@table = table
	end
	def [](col)
		@db.get_first_value("SELECT #{col} FROM #{@table} WHERE id=?", @id)
	end
	def []=(col, val)
		@db.execute("UPDATE #{@table} SET #{col}=? WHERE id=?", val, @id)
	end
end

class Links
	def initialize(db)
		@db = db
	end
	def clear(id); @db.execute("DELETE FROM links WHERE page=?", id); end
	def add(from, to)
		@db.execute "INSERT INTO links VALUES(?, ?)", from, to unless \
		  @db.get_first_value("SELECT count(*) FROM links WHERE page=? AND ref=?", \
		  from, to).to_i > 0
	end
	def self.internal?(href)
		!(href.include? "/" or href.include? "?" or href =~ /^mailto:/ or href.include? "@")
	end
	def self.niceify(href)
	end
	def to(ref)
		@db.execute("SELECT page FROM links WHERE ref=?", to) do |row|
			yield row[0]
		end
	end
	def from(page)
		@db.execute("SELECT ref FROM links WHERE page=?", page) do |row|
			yield row[0]
		end
	end
end

class Auth
	def self.create(db, table)
		tab =
			[:userid => "INTEGER PRIMARY KEY"] +
			[:name => "TEXT UNIQUE"] +
			[:password => "TEXT"] +
			[:permissions => "INTEGER"] +
			[:token => "TEXT"]
		Table.create db, table, tab, {}
	end
	def initialize(db, table)
		@tab = Table.new db, table
	end
	def adduser(name, passwd, perms)
		begin
			@tab.add({:userid => "NULL", :name => name, :password => SHA1.hexdigest(passwd), :permissions => perms, :token => ""})
			:ok
		rescue SQLite3::SQLException
			:badname
		end
	end
	def auth(name, passwd)
		user = @tab.search_by :name, name
		pwhash = user[:password]
		return :nouser unless pwhash
		return :badpass unless pwhash == SHA1.hexdigest(passwd)
		user[:token] = SHA1.hexdigest rand.to_s
	end
	def tokenauth(token)
		if @tab.search_by :token, token; true; else; false; end
	end
	def perms(name)
		user = @tab.search_by :name, name
		nil unless user
		user[:permissions]
	end
end

module SuperString
	def nwm2html()
		out = []
		nxt = nil
		self.split("\n").each do |line|
			if line =~ /^ {4,}.*$/
				out += ["#{nxt}<pre>"] unless nxt == "</pre>"
				out += [line.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&lt;")]
				nxt = "</pre>"
				next
			end
			line.gsub! /\\./ {|s| "&##{s};"}
			if line =~ /^(\={2,6})(.*?)\1$/
				line = "<h#{$1}>#{$2}</h#{$1}>"
				nxt = ""
			elsif line =~ /^# (.*)$/
				out += ["#{nxt}<ol>"] unless nxt == "</ol>"
				line = "<li>#{$1}</li>"
				nxt = "</ol>"
			elsif line =~ /^\* (.*)$/
				out += ["#{nxt}<ul>"] unless nxt == "</ul>"
				line = "<li>#{$1}</li>"
				nxt = "</ul>"
			elsif line =~ /^[[:space:]]*$/
				out += [nxt]
				nxt = ""
			else
				out += ["#{nxt}<p>"] unless nxt == "</p>"
				set nxt "</p>"
			end
			line.gsub! /\[\[(?!\[)(.*?)(?: (.*?))?\]\]/ do |match|
				texturl = Links.uglify($1)
				unless $2
					Element.link(texturl, Links.niceify($1))
				else
					Element.link(texturl, $2)
				end
			end

			line.gsub!(/{{(.*?) (.*?)}}/, '<img src="\1" alt="\2" title="\2" />')
			line.gsub!(/\b_(.*?[^\\])_\b/, '<em>\1</em>')
			line.gsub!(/(?!\b)\*(.*?[^\\])\*(?!\b)/, '<strong>\1</strong>')
			line.gsub!(/``(.*?)''/, '&ldquo;\1&rdquo;')
			line.gsub!(/(?!\b)@(.*?)@(?!\b)/, '<code>\1</code>')
			out += [line]
		end
		out += [nxt]
		out.join ""
	end
	def textile2html()
	end
	def markdown2html()
	end
	def diff(b)
		a = self.split
		b = b.split "\n" if b.respond_to? :lines

		asubs, bsubs = lcs a, b

		# If a line number is not in asubs, it's a deletion from a
		dlines = []
		a.length.times {|k| dlines += [k] unless asubs.member? k}

		# If a line number is not in bsubs, it's an addition to a
		alines = []
		b.length.times {|k| alines += [[k, b[k]]] unless bsubs.member? k}

		"d#{dlines.join ","}\n#{alines.collect {|i| "#{i[0]}\t#{i[1]}"}.join "\n"}"
	end
	def lcs(a, b)
		eqv = {}
		b.each_with_index do |str, idx|
			eqv[str] = [] unless eqv.member? str
			eqv[str] += [idx]
		end

		dlcs = [[-1, -1, []], [a.length, b.length, []]]
		k = 0
		i = 0
		a.each do |str|
			if eqv.member? str
				c = dlcs[0]; r = 0
				eqv[str].each do |j|
					max = k; min = r; s = k + 1
					while max >= min
						mid = (max + min) / 2
						bmid = dlcs[mid][1]
						if j == bmid
							break
						elsif j < bmid
							max = mid - 1
						else
							s = mid
							min = mid + 1
						end
					end
					next if j == dlcs[mid][1] || s > k
					newc = [i, j, dlcs[s]]
					dlcs[r] = c
					c = newc
					r = s + 1
					if s >= k
						dlcs += dlcs[-1]
						k += 1
						break
					end
				end
				dlcs[r] = c
			end
			i += 1
		end
		q = dlcs[k]
		seta = []; setb = []
		while q[0] >= 0
			k -= 1
			seta[k] = q[0]
			setb[k] = q[1]
			q = q[2]
		end

		[seta, setb]
	end
	def patch(patch)
		dlines = []
		alines = []
		a = self.split "\n"
		patch.split("\n").each do |line|
			if line[0].chr == "d"
				dlines += line[1..-1].split(",").collect {|i| i.to_i}
			else
				lnum, text = line.split "\t", 2
				alines += [[lnum.to_i, text]]
			end
		end
		dlines.each {|d| a.delete_at d}
		alines.each {|aline| a.insert(aline[0], aline[1])}
		a.join("\n")
	end
	def patch!(patch)
		self[0..-1] = patch(patch)
	end
	def scriptpage(ruby)
	end

	private :lcs
end

class String
	include SuperString
end

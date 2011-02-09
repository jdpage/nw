*nw* stands for nano wiki. The current version is a few hundred lines of Tcl code long, and powers my wiki. The next version will be who knows how many lines of Ruby long, and will replace the Tcl version.

The goal is to be a small, fast, lightweight, reasonably feature-complete wiki. It will be easy to hack on. It will also feed your dog and make you tea when you're sad. I hope. At the moment, it's very function-over-form, with no real themeing support short of editing the code.

Features:

* A simple form of [wikimarkup](http://alt.jd-page.com/nw/wikimarkup). It's actually more related to Textile than normal wiki markup.
* Small, fast, and reasonably simple. It was simpler when it was 200 lines long.
* TOC page, history pages, and a "list all pages" function.
* Authentication. This is only listed as a feature because it didn't used the have it.

Issues:

* A complete copy of each page is stored with each revision. I'll move to diffs at some point.
* No admin interface.
* Rather ugly and/or boring.
* There may be bugs in the markup parser. I think I got them all, though.

This project rocks a BSD license.


Copyright (c) 2010, Jonathan Page All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
3. The names of its contributors may not be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

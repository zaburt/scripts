#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#

require 'net/http'

URL = 'http://www.koeri.boun.edu.tr/scripts/lst0.asp'

downloaded_raw = Net::HTTP.get(URI(URL))
downloaded_raw.force_encoding(Encoding::Windows_1254)
downloaded = downloaded_raw.encode(Encoding::UTF_8)

full_page = downloaded.split("\r\n")
start = full_page.find_index{|k| k.start_with?('<pre>')} + 5
stop = full_page.find_index{|k| k.start_with?('</pre>')} - 2
data = full_page[start..stop]

puts data


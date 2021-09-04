#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#

require 'json'
require 'csv'

TSV_FILE = 'name.basics.tsv'
OUTPUT_FILE = 'imdb_name_basics_small.json'

output = {}

# sed -i -e 's/"//g' -e '1d' name.basics.tsv
raw_data = IO.read(TSV_FILE).split("\n", 2)[1].gsub(/"/, '')
parsed_csv = CSV.parse(raw_data, :col_sep => "\t")

parsed_csv.each do |row|
  nm_id = row[0]
  name = row[1]&.downcase
  next if output.has_key?(name)

  output[name] = nm_id
end

sorted = output.sort.to_h

File.open(OUTPUT_FILE, 'w') do |f|
  f.write JSON.pretty_generate(sorted)
end



#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#

require 'net/telnet'
require 'pp'

target_host = ARGV[0] || 'localhost'
target_port = ARGV[1] || 11211
@slab_rows = []
@slabs = []

@target_connection = Net::Telnet::new(
  'Host' => target_host,
  'Port' => target_port,
  'Timeout' => 3
)

def fetch_all_keys
  matches = @target_connection.cmd('String' => 'stats items', 'Match' => /^END/).scan(/STAT items:(\d+):number (\d+)/)
  @slabs = matches.inject([]) do |items, item|
    items << Hash[*['id','items'].zip(item).flatten]
    items
  end

  # longest_key_len = 0
  @slabs.each do |slab|
    @target_connection.cmd('String' => "stats cachedump #{slab['id']} #{slab['items']}", 'Match' => /^END/) do |c|
      # pp c
      matches = c.scan(/^ITEM (.+?) \[(\d+) b; (\d+) s\]$/).each do |key_data|
        cache_key, bytes, expires_time = key_data
        @slab_rows << [slab['id'], Time.at(expires_time.to_i), bytes, cache_key]
        # longest_key_len = [longest_key_len,cache_key.length].max
      end
    end
  end

  # longest_key_len
end

def list_all_keys
  fetch_all_keys

  headings = %w(ID Expires Bytes Cache\ Key)
  row_format = %Q(|%8s | %28s | %12s | %s)
  row_format_heading = %Q( %-8s | %-28s | %-12s | %s)

  puts
  puts row_format_heading % headings
  # puts '-' * (60 + longest_key_len)
  puts '-' * 100
  @slab_rows.each{|row| puts row_format % row}
  puts
end

def get_value(cache_key)
  content = @target_connection.cmd('String' => "get #{cache_key}", 'Match' => /^END/) {|c| c}
  # @target_connection.cmd("String" => "get #{cache_key}", "Match" => /^END/) { |c| puts c }
  # content = content.ascii_only? ? content : 'Not ASCII'
  # pp content.inspect
  puts content
end

list_all_keys
# get_value(ARGV[2])

@target_connection.close



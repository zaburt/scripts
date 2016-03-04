#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#

require 'net/telnet'

target_host = ARGV[0] || 'localhost'
target_port = ARGV[1] || 11211
cache_dump_limit = ARGV[2] || 100
slab_ids = []

target_connection = Net::Telnet::new(
  'Host' => target_host,
  'Port' => target_port,
  'Timeout' => 3
)

target_connection.cmd('String' => 'stats items', 'Match' => /^END/) do |c|
  matches = c.scan(/STAT items:(\d+):/)
  slab_ids = matches.flatten.uniq
end


puts
puts "Expires At\t\t\t\tCache Key"
puts '-'* 80

slab_ids.each do |slab_id|
  target_connection.cmd('String' => "stats cachedump #{slab_id} #{cache_dump_limit}", 'Match' => /^END/) do |c|
    matches = c.scan(/^ITEM (.+?) \[(\d+) b; (\d+) s\]$/).each do |key_data|
      cache_key, bytes, expires_time = key_data
      humanized_expires_time = Time.at(expires_time.to_i).to_s
      puts "[#{humanized_expires_time}]\t#{cache_key}"
    end
  end
end

puts
target_connection.close


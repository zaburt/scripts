#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#
# a script to manage and get info for a given memcahce server
# for more info run
#
#   ruby memcahce_client.rb -h
#

require 'net/telnet'
require 'optparse'
require 'pp'

CMD_STATS = 'stats'
CMD_STATS_CACHEDUMP = 'stats cachedump %s %s'
CMD_STATS_ITEMS = 'stats items'
CMD_STATS_SLABS = 'stats slabs'
CMD_FLUSH = 'touch %s 1'
CMD_DELETE = 'delete %s'
CMD_GET = 'get %s'

MATCHER_CACHE_KEY = /^ITEM (.+?) \[(\d+) b; (\d+) s\]$/
MATCHER_DELETE = /^DELETED|NOT_FOUND/
MATCHER_END = /^END/
MATCHER_FLUSH = /^TOUCHED|NOT_FOUND/
MATCHER_GET = /^END|NOT_FOUND/
MATCHER_SLAB_ITEM = /STAT items:(\d+):number (\d+)/
MATCHER_STATS = /STAT ([^ ]*) (.*)/
MATCHER_STATS_SLABS = /STAT (\d+):([^ ]*) (.*)/
MATCHER_STATS_ITEMS = /STAT items:(\d+):([^ ]*) (.*)/

PRINT_HEADINGS = %w(ID Expires Bytes Cache\ Key)
PRINT_ROW_FORMAT = %Q(|%8s | %28s | %12s | %s)
PRINT_ROW_FORMAT_HEADING = %Q( %-8s | %-28s | %-12s | %s)

ACTIONS = [:list, :get, :flush, :flush_all, :delete, :delete_all, :stats, :stats_slabs, :stats_items]

@options = {
  :server => 'localhost',
  :port => 11211,
  :timeout => 3,
  :action => :list_keys,
  :cache_key => nil,
  :cache_key_file => nil,
  :namespace => nil,
  :command => nil,
  :flush_before_delete => false,
  :verbose => false
}

OptionParser.new do |opts|
  opts.banner = "Usage: ruby memcache_client.rb [options]\nDo not forget to provide a namespace when flushing and deleting\n\n"

  opts.on('-s', '--server HOST', 'memcache server host (default: localhost)') do |s|
    @options[:server] = s
  end

  opts.on('-p', '--port N', Integer, 'memcache server port (default: 11211)') do |p|
    @options[:port] = p
  end

  opts.on('--timeout N', Integer, 'memcache connection timeout (default: 3)') do |t|
    @options[:timeout] = t
  end

  opts.on('-a', '--action ACTION', ACTIONS, "choose what to do (#{ACTIONS.join(', ')})") do |a|
    @options[:action] = a
  end

  opts.on('-k', '--key KEY', 'cache key to use in action') do |k|
    @options[:cache_key] = k
  end

  opts.on('-f', '--file KEYFILE', 'text file with a list of cache key') do |f|
    @options[:cache_key_file] = f
  end

  opts.on('-c', '--command COMMAND', 'run a custom command') do |c|
    @options[:command] = c
  end

  opts.on('-n', '--namespace NAMESPACE', 'prefix for cache keys to process') do |n|
    @options[:namespace] = n
  end

  opts.on('-b', '--[no-]flush_before_delete', 'flush cache keys before deleting') do |f|
    @options[:flush_before_delete] = f
  end

  opts.on('-v', '--[no-]verbose', 'Run verbosely') do |v|
    @options[:verbose] = v
  end
end.parse!

@slabs = []
@slab_items = []
@key_list = []
@memcache_connection = nil

def start_connection
  @memcache_connection = Net::Telnet::new(
    'Host' => @options[:server],
    'Port' => @options[:port],
    'Timeout' => @options[:timeout]
  )
end

def end_connection
  @memcache_connection.close
end

def command(cmd, matcher = MATCHER_END)
  resp = @memcache_connection.cmd('String' => cmd, 'Match' => matcher)

  if @options[:verbose]
    puts "\nRUNNING: #{cmd}"
    pp resp
  end

  resp
end

def build_dynamic_hash(matcher)
  matcher.inject({}) do |ret, (c, key, value)|
    ret[c] ||= {}
    ret[c][key] = value
    ret
  end
end

def server_stats
  command(CMD_STATS, MATCHER_END)
end

def server_stats_slabs
  command(CMD_STATS_SLABS, MATCHER_END)
end

def server_stats_items
  command(CMD_STATS_ITEMS, MATCHER_END)
end

def server_stats_hash
  Hash[server_stats.scan(MATCHER_STATS).sort]
end

def server_stats_slabs_hash
  matcher = server_stats_slabs.scan(MATCHER_STATS_SLABS)
  build_dynamic_hash(matcher)
end

def server_stats_items_hash
  matcher = server_stats_items.scan(MATCHER_STATS_ITEMS)
  build_dynamic_hash(matcher)
end

def delete_keys
  server_response = {}

  @key_list.each do |cache_key|
    resp = command(CMD_DELETE % cache_key, MATCHER_DELETE)
    server_response[cache_key] = resp.strip
  end

  server_response
end

def flush_keys
  server_response = {}

  @key_list.each do |cache_key|
    resp = command(CMD_FLUSH % cache_key, MATCHER_FLUSH)
    server_response[cache_key] = resp.strip
  end

  server_response
end

def get_keys
  server_response = {}

  @key_list.each do |cache_key|
    resp = command(CMD_GET % cache_key, MATCHER_GET)
    server_response[cache_key] = resp.strip
  end

  server_response
end

def flush_and_delete_keys
  if @options[:flush_before_delete]
    # set expiration of keys as now
    flush_keys

    # make sure expiration for caches is in the past (in seconds)
    sleep(1)
  end

  delete_keys
end

def print_cache_keys
  puts
  puts PRINT_ROW_FORMAT_HEADING % PRINT_HEADINGS
  puts '-' * 100
  @slab_items.each{|row| puts PRINT_ROW_FORMAT % row}
  puts
end

def print_server_stats_hash(stat_hash)
  stat_keys = stat_hash.first[1].keys.sort
  headers = ['slab_id'] + stat_keys
  col_format = headers.map{|k| "%#{k.size}s"}.join(' | ')
  title = headers.join(' | ')
  puts title
  puts '-' * title.size

  stat_hash.each do |slab_id, values|
    data = [slab_id] + stat_keys.map{|k| values[k]}
    puts col_format % data
  end
end

def memcache_slabs
  matches = server_stats_items.scan(MATCHER_SLAB_ITEM)

  matches.inject([]) do |items, item|
    items << Hash[*['id','items'].zip(item).flatten]
    items
  end
end

def fetch_cache_keys
  @slabs = memcache_slabs

  @slabs.each do |slab|
    resp = command(CMD_STATS_CACHEDUMP % [slab['id'], slab['items']], MATCHER_END)

    resp.scan(MATCHER_CACHE_KEY).each do |key_data|
      cache_key, bytes, expires_time = key_data
      next if @options[:namespace] && !cache_key.start_with?(@options[:namespace])

      @slab_items << [slab['id'], Time.at(expires_time.to_i), bytes, cache_key]
    end
  end

  @slab_items
end

def fill_key_list_from_cache_keys
  fetch_cache_keys
  @key_list = @slab_items.map(&:last)
end

def fill_key_list_from_options
  if @options[:cache_key]
    @key_list = [@options[:cache_key]]
  elsif @options[:cache_key_file]
    @key_list = IO.read(@options[:cache_key_file]).split("\n").reject(&:empty?)
  end
end

def run
  fill_key_list_from_options

  if @options[:verbose]
    puts "\nWorking on keys:"
    @key_list.each{|k| puts k}
  end

  start_connection

  case @options[:action]
  when :list_keys
    fetch_cache_keys
    print_cache_keys
  when :get
    get_value(@options[:key])
  when :flush
    flush_keys
  when :flush_all
    if @options[:namespace]
      fill_key_list_from_cache_keys
      flush_keys
    else
      puts 'You need to provide a namespace to flush multiple keys'
    end
  when :delete
    flush_and_delete_keys
  when :delete_all
    if @options[:namespace]
      fill_key_list_from_cache_keys
      flush_and_delete_keys
    else
      puts 'You need to provide a namespace to delete multiple keys'
    end
  when :stats
    puts server_stats
  when :stats_items
    print_server_stats_hash(server_stats_items_hash)
  when :stats_slabs
    print_server_stats_hash(server_stats_slabs_hash)
  end

  end_connection
end

puts "Options: #{@options.inspect}" if @options[:verbose]
run



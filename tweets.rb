require 'eventmachine'
require 'em-http'
require 'em-http/middleware/oauth'
require 'yaml'
require 'yajl'

if ARGV[0].nil?
  puts "Please specify a term: \n" +
    "*** Usage: `bundle exec ruby tweets.rb <term>`\n" +
    "    e.g. `bundle exec ruby tweets.rb %40twitter,%23twitter` to track either @twitter OR #twitter"
  exit 1
end

CONFIG = YAML.load_file('config.yml')
twitter_api_base_url = CONFIG['twitter']['api_base_url']
twitter_oauth_config = CONFIG['twitter']['oauth']

watson_credentials = CONFIG['watson']['credentials']

EM.run do
  conn = EventMachine::HttpRequest.new(twitter_api_base_url)
  conn.use EventMachine::Middleware::OAuth, twitter_oauth_config.map{ |k, v| [k.to_sym, v] }.to_h

  http = conn.get(path: "/1.1/statuses/filter.json?track=#{ARGV[0]}")
  parser = Yajl::Parser.new
  parser.on_parse_complete = -> (obj) { puts "obj_parsed"; puts obj.inspect }

  http.stream do |chunk|
    puts "received_chunk: #{chunk.size}"
    parser << chunk
  end

  # em-http invokes callback function when the request is fully parsed
  http.callback do
    EM.stop
  end

  http.errback do
    puts "*** errback"
    EM.stop
  end
end

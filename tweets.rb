require 'eventmachine'
require 'em-http'
require 'em-http/middleware/oauth'
require 'yaml'
require 'yajl'
require 'net/http'
require 'json'

if ARGV[0].nil?
  puts "Please specify a term: \n" +
    "*** Usage: `bundle exec ruby tweets.rb <term>`\n" +
    "    e.g. `bundle exec ruby tweets.rb \"twitter,fabric\"` to track either twitter OR fabric"
  exit 1
end

CONFIG = YAML.load_file('config.yml')
twitter_api_base_url = CONFIG['twitter']['api_base_url']
twitter_oauth_config = CONFIG['twitter']['oauth']

def analyze_tone(text)
  watson_api_base_url = CONFIG['watson']['api_base_url']
  watson_credentials = CONFIG['watson']['credentials']
  puts '---------------'
  puts text
  return unless should_process(text, ARGV[0])

  uri = URI(watson_api_base_url)
  resp = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
    req = Net::HTTP::Post.new(uri)
    req.content_type = 'application/json'
    req.body = { text: text }.to_json
    req.basic_auth(watson_credentials['username'], watson_credentials['password'])
    resp = http.request(req) # Net::HTTPResponse object
  end

  tone_categories = JSON.parse(resp.body)['document_tone']['tone_categories'] if resp.is_a?(Net::HTTPSuccess)

  puts tone_categories.inspect
  tone_categories
end

def should_process(text, input)
  return if text.nil? || input.nil?
  # Discard the text that are not # or @
  keywords = input.downcase.split(/,\s*/)
  text.downcase.split(' ').any? do |word|
    keywords.any? { |keyword| word == "@#{keyword}" || word == "##{keyword}" }
  end
end

EM.run do
  conn = EventMachine::HttpRequest.new(twitter_api_base_url)
  conn.use EventMachine::Middleware::OAuth, twitter_oauth_config.map{ |k, v| [k.to_sym, v] }.to_h

  path = "/1.1/statuses/filter.json?track=#{URI.escape(ARGV[0])}"
  # Keep streaming connection open and disable inactivity timeout,
  # see: https://github.com/igrigorik/em-http-request/wiki/Redirects-and-Timeouts
  http = conn.get(path: path, inactivity_timeout: 0)
  parser = Yajl::Parser.new
  parser.on_parse_complete = -> (obj) { analyze_tone(obj['text'])  }

  http.stream do |chunk|
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

require 'eventmachine'
require 'em-http'
require 'em-http/middleware/oauth'
require 'yaml'
require 'yajl'
require 'net/http'
require 'json'
require_relative './lib/watson/alchemy'
require_relative './lib/watson/tone_analyzer'
require_relative './lib/slack_client'

if ARGV[0].nil?
  puts "Please specify a term: \n" +
    "*** Usage: `bundle exec ruby tweets.rb <term>`\n" +
    "    e.g. `bundle exec ruby tweets.rb \"twitter,fabric\"` to track either twitter OR fabric"
  exit 1
end

CONFIG = YAML.load_file('config.yml')
SLACK_CLIENT = SlackClient.new(CONFIG['slack']['carebot']['api_token'])

def analyze(obj)
  puts '------------------'
  puts obj['text']
  return unless should_process(obj['text'], ARGV[0])

  analyze_sentiment(obj)
end

def analyze_sentiment(obj)
  text = obj['text']

  alchemy_resp = Watson::Alchemy.new(CONFIG['watson']).analyze(text)

  sentiment = alchemy_resp && alchemy_resp['docSentiment']
  return unless sentiment

  if sentiment['type'] == 'negative' && sentiment['score'].to_f < -0.75
    tones = analyze_tones(obj)
    screen_name = obj['user']['screen_name']
    avatar = obj['user']['profile_image_url']
    options = {
      ts: obj['timestamp_ms'],
      sentiment_score: sentiment['score'],
      title: "[tweetID #{obj['id']}] Negative tweet from @#{screen_name}",
      title_link: "https://twitter.com/#{screen_name}/status/#{obj['id']}",
      tones: tones,
      author: screen_name,
      author_icon: avatar
    }
    post_to_slack(text, options)
  elsif sentiment['type'] == 'neutral'
    # TODO: handle negative
  elsif sentiment['type'] == 'positive'
    # TODO: handle positive
  end
end

def analyze_tones(obj)
  text = obj['text']
  ta_resp = Watson::ToneAnalyzer.new(CONFIG['watson']).analyze(text)
  ta_resp && ta_resp['document_tone']['tone_categories']
end

def should_process(text, input)
  return if text.nil? || input.nil?
  # Discard the text that are not # or @
  keywords = input.downcase.split(/,\s*/)
  text.downcase.split(' ').any? do |word|
    keywords.any? { |keyword| word == "@#{keyword}" || word == "##{keyword}" }
  end
end

def post_to_slack(text, options = {})
  puts "posting to slack: "
  SLACK_CLIENT.post(text, options)
end

EM.run do
  twitter_api_base_url = CONFIG['twitter']['api_base_url']
  twitter_oauth_config = CONFIG['twitter']['oauth']
  conn = EventMachine::HttpRequest.new(twitter_api_base_url)
  conn.use EventMachine::Middleware::OAuth, twitter_oauth_config.map{ |k, v| [k.to_sym, v] }.to_h

  path = "/1.1/statuses/filter.json?track=#{URI.escape(ARGV[0])}"
  # Keep streaming connection open and disable inactivity timeout,
  # see: https://github.com/igrigorik/em-http-request/wiki/Redirects-and-Timeouts
  http = conn.get(path: path, inactivity_timeout: 0)
  parser = Yajl::Parser.new
  parser.on_parse_complete = -> (obj) { analyze(obj)  }

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

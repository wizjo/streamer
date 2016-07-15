require 'eventmachine'
require 'em-http'
require 'em-http/middleware/oauth'
require 'yaml'
require 'yajl'
require 'net/http'
require 'json'
require_relative './lib/watson/alchemy'
require_relative './lib/watson/tone_analyzer'
require_relative './lib/watson/classifier'
require_relative './lib/slack_client'
require_relative './lib/twitter_client'

if ARGV[0].nil?
  puts "Please specify a term: \n" +
    "*** Usage: `bundle exec ruby tweets.rb <term>`\n" +
    "    e.g. `bundle exec ruby tweets.rb \"twitter,fabric\"` to track either twitter OR fabric"
  exit 1
end

CONFIG = YAML.load_file('config.yml')
SLACK_CLIENT = SlackClient.new(CONFIG['slack']['carebot']['api_token'])
TWITTER_CLIENT = TwitterClient.new(CONFIG['twitter']['oauth'])
WATSON_CLASSIFIER = Watson::Classifier.new(CONFIG['watson'])
EMOTION_CLASSIFIER_ID = WATSON_CLASSIFIER.classifier_id_by_name('carebot')
TOPIC_CLASSIFIER_ID = WATSON_CLASSIFIER.classifier_id_by_name('topic')

def analyze(obj)
  return unless should_process(obj['text'], ARGV[0])
  puts '------------------'
  puts obj['text']
  analyze_sentiment(obj)
end

def analyze_sentiment(obj)
  text = obj['text']

  alchemy_resp = Watson::Alchemy.new(CONFIG['watson']).analyze(text)
  sentiment = alchemy_resp && alchemy_resp['docSentiment']
  return unless sentiment

  # Use Tone Analyzer
  emotion_tone = get_emotion_tone(obj)
  sentiment_score = sentiment['score'].to_f
  # Confidence score is > 0.75
  if sentiment_score.abs >= 0.75
    topic_category = get_topic_category(obj)
    puts topic_category.inspect
    puts emotion_tone.inspect
    puts "---- auto reply:"
    puts obj.inspect
    # TODO: auto reply
    # TWITTER_CLIENT.post(message, in_reply_to_status_id)
  elsif sentiment_score < 0.25
    # If Watson is not confident *enough*, post to Slack for CS person to categorize
    color = case sentiment['type']
      when 'negative' then '#EB4D5C'
      when 'neutral' then '#CACACA'
      when 'positive' then '#42b879'
      end
    screen_name = obj['user']['screen_name']
    avatar = obj['user']['profile_image_url']
    options = {
      channel: 'training',
      ts: obj['timestamp_ms'].to_i,
      title: "[tweetID #{obj['id']}] tweet from @#{screen_name}",
      color: color,
      author: screen_name,
      author_icon: avatar
    }
    post_to_slack([
      text,
      emotion_tone.to_json,
      "https://twitter.com/#{screen_name}/status/#{obj['id']}"].join("\n"), options)
  end
end

def get_topic_category(obj)
  topic_category = WATSON_CLASSIFIER.classify(obj['text'], TOPIC_CLASSIFIER_ID)
  top_topic = topic_category['classes'].find{ |c| c['class_name'] == topic_category['top_class'] }
  { name: top_topic['class_name'], confidence: top_topic['confidence'].to_f }
end

def analyze_tones(obj)
  text = obj['text']
  ta_resp = Watson::ToneAnalyzer.new(CONFIG['watson']).analyze(text)
  ta_resp && ta_resp['document_tone']['tone_categories']
end

def get_emotion_tone(obj)
  tones = analyze_tones(obj)
  emotion_tone = tones.find{ |tone| tone['category_id'] == 'emotion_tone' }
  sorted = emotion_tone && emotion_tone['tones'].sort_by{ |tone| tone['score'].to_f }.reverse
  sorted.map{ |h| [h['tone_name'], h['score']] }.to_h
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

begin
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
    parser.on_parse_complete = -> (obj) { analyze(obj) }

    # em-http invokes callback function when the request is fully parsed
    http.callback { EM.stop }
    http.errback { EM.stop }
    http.stream { |chunk| parser << chunk }
  end
rescue Exception => e
  puts e.inspect
  EM.stop
end

# Given some tweet text, use watson-alchemy to get sentiment and toner to get tone

require 'yaml'
require 'faraday'
require 'json'

CONFIG = YAML.load_file('config.yml')

text = "I do #lovetwitter's @fabric. Everything @TwitterDev is amazing. Seamless services for developers & especially mobile developers"

if ARGV[0].nil?
  puts "No text detected. Using sample tweet. Alternatively: \n" +
    "*** Usage: `bundle exec ruby enrich.rb <text_to_analyze>`"
end

text = ARGV[0] if ARGV[0]

alchemy_base_url = CONFIG['alchemy']['api_base_url']
alchemy_api_key = CONFIG['alchemy']['api_key']

watson_url = CONFIG['watson']['api_base_url']
watson_credentials = CONFIG['watson']['credentials']

# alchemy
alchemy_connection = Faraday.new(url: alchemy_base_url) do |builder|
  builder.request :url_encoded
  builder.adapter :excon
end

# see http://www.ibm.com/watson/developercloud/alchemy-language/api/v1/?curl#combined-call
parameters = {:apikey => alchemy_api_key, :text => text, :extract => 'entities,doc-sentiment', :outputMode => 'json'}

alchemy_response = alchemy_connection.post('', parameters)
alchemy_parsed = JSON.parse(alchemy_response.body)

# tone-analyzer
tone_analyzer = Faraday.new(url: watson_url) do |builder|
  builder.adapter :excon
  builder.headers['Content-Type'] = 'application/json'
end

# see http://www.ibm.com/watson/developercloud/tone-analyzer/api/v3/?curl#methods

tone_analyzer.basic_auth(watson_credentials['username'], watson_credentials['password'])
watson_response = tone_analyzer.post('', {:text => text}.to_json)
watson_parsed = JSON.parse(watson_response.body)

return_value = {:tweet => text, :sentiment => alchemy_parsed['docSentiment'], :entities => alchemy_parsed['entities'], :tone => watson_parsed['document_tone']}
puts JSON.pretty_generate(return_value)

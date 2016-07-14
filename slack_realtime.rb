require 'slack-ruby-client'
require 'yaml'
require_relative './lib/twitter_client'

class SlackRealtimeClient
  def initialize(api_key)
    Slack.configure { |config| config.token = api_key }
    Slack::RealTime::Client.config { |config| config.user_agent = 'Slack Ruby Client' }
    client = Slack::RealTime::Client.new

    client.on :hello do
      puts "Successfully connected, welcome '#{client.self.name}' to the '#{client.team.name}' team at https://#{client.team.domain}.slack.com."
    end
    client.on :message do |data|
      on_message_handler(data, client)
    end
    client.on :close do |_data|
      puts 'Client is about to disconnect'
    end
    client.on :closed do |_data|
      puts 'Client has disconnected successfully!'
    end

    client.start!
  end

  private
  def on_message_handler(data, client)
    return unless data.text
    text = data.text.downcase
    return if data.user == 'U1RELQNSV' # Does not answer question from carebot itself
    return unless text.match(/@u1relqnsv/) # Does not handle requests unless carebot is at mentioned

    case text
    when /hi|hello/i
      client.message channel: data.channel, text: "Hi <@#{data.user}>!"
    when /classify (?<tweet_id>\d+) as (?<category>.+)/
      tweet_id = $~[:tweet_id]
      category = $~[:category]
      puts [tweet_id, category].inspect
      text = TWITTER_CLIENT.get_tweet_text(tweet_id)
      client.message channel: data.channel, text: "Classifying the following message as \"#{category}\":\n>#{text}"
    else
      client.message channel: data.channel, text: "To start training me, please say:\n@carebot classify <tweet_id> as <category>"
    end
  end
end

CONFIG = YAML.load_file('config.yml')
TWITTER_CLIENT = TwitterClient.new(CONFIG['twitter']['oauth'])
SlackRealtimeClient.new(CONFIG['slack']['carebot']['api_token'])

require 'slack-ruby-client'
require 'yaml'

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
    text = data.text.downcase
    return unless text.match(/@u1relqnsv/)
    puts 'continue....'
    
    case text
    when /hi|hello/i
      puts 'user is friendly :)'
      client.message channel: data.channel, text: "Hi <@#{data.user}>!"
    else
      puts 'ambiguous :/'
      client.message channel: data.channel, text: "Hello <@#{data.user}>! How can I help you today?"
    end
  end
end

CONFIG = YAML.load_file('config.yml')
SlackRealtimeClient.new(CONFIG['slack']['carebot']['api_token'])

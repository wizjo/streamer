require 'slack-ruby-client'

class SlackRealtimeClient
  def initialize(api_key)
    Slack.configure { |config| config.token = api_key }
    Slack::RealTime::Client.config { |config| config.user_agent = 'Slack Ruby Client' }
    client = Slack::RealTime::Client.new

    client.on :message -> (data) { on_message_handler(data) }

    client.start!
  end

  def on_message_handler(data)
    case data.text
    when 'bot hi' then
      client.message channel: data.channel, text: "Hi <@#{data.user}>!"
    when /^bot/ then
      client.message channel: data.channel, text: "Sorry <@#{data.user}>, what?"
    end
  end

end

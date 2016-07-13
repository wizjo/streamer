require 'slack-ruby-client'

class SlackClient
  def initialize(api_key)
    Slack.configure { |config| config.token = api_key }
    Slack::Web::Client.config { |config| config.user_agent = 'Slack Ruby Client' }
    @client = Slack::Web::Client.new
  end

  def post(message, options = {})
    @client.chat_postMessage(
      channel: options[:channel] || '#random',
      text: message,
      as_user: (options[:as_user].nil? ? true : options[:as_user])
    )
  end
end

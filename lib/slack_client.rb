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
      as_user: false,
      icon_url: 'https://d30y9cdsu7xlg0.cloudfront.net/png/6704-200.png',
      username: 'CareBot',
      attachments: [{
          "color": "#EB4D5C",
          "pretext": options[:title],
          "author_name": options[:author],
          "author_link": "https://twitter.com/#{options[:author]}",
          "author_icon": options[:author_icon],
          "title": options[:title_link],
          "title_link": options[:title_link],
          "text": message,
          "footer": "Twitter",
          "footer_icon": "https://a.slack-edge.com/66f9/img/services/twitter_48.png",
          "ts": options[:ts]
      }]
    )
  end
end

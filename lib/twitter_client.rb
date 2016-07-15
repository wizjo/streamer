require 'twitter'

class TwitterClient
  def initialize(config)
    @client = Twitter::REST::Client.new do |client|
      %w(consumer_key consumer_secret access_token access_token_secret).each do |attr|
        client.send("#{attr}=".to_sym, config[attr])
      end
    end
  end

  def get_tweet_text(tweet_id)
    tweet = @client.status(tweet_id)
    tweet && tweet.full_text
  end

  def post(message, in_reply_to_status_id = nil)
    puts [message, in_reply_to_status_id].inspect
    @client.update(message, in_reply_to_status_id: in_reply_to_status_id)
  end

end

require 'fileutils'
require 'slack-ruby-client'
require 'yaml'
require_relative './lib/twitter_client'
require_relative './lib/watson/classifier'

class SlackRealtimeClient
  def initialize(api_key, output_path = 'out/training_data.csv')
    @output_path = output_path
    ensure_dir_exists(@output_path)

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

  def ensure_dir_exists(output_path)
    paths = output_path.split('/')
    dir = paths.take(paths.length - 1).join('/')
    FileUtils.mkdir_p dir
  end

  def on_message_handler(data, client)
    # Only listen to "#training" channel and when text is present
    return unless data.text
    return unless data.channel == 'C1S0326RF'

    text = data.text.downcase
    return if data.user == 'U1RELQNSV' # Does not answer question from carebot itself
    return unless text.match(/@u1relqnsv/) # Does not handle requests unless carebot is at mentioned

    case text
    when /hi|hello/i
      client.message channel: data.channel, text: "Hi <@#{data.user}>!"
    when /bye/i
      client.message channel: data.channel, text: "See you later <@#{data.user}>! Have a good one!"
    when /classify (?<tweet_id>\d+) as (?<category>.+)/
      tweet_id = $~[:tweet_id]
      category = $~[:category]
      puts [tweet_id, category].inspect
      text = TWITTER_CLIENT.get_tweet_text(tweet_id)

      append_to_file(@output_path, text, category)
      refresh_training_data(@output_path)
      client.message channel: data.channel, text: "Classifying the following message as \"#{category}\":\n#{text}"
    else
      client.message channel: data.channel, text: "To start training me, please say:\n@carebot classify <tweet_id> as <category>"
    end
  end

  def append_to_file(file_name, text, category)
    File.open(file_name, 'a') do |f|
      # Escape newline characters in the message body to prserve the structure of CSV
      f.write [text, category].map{ |str| "\"#{str.gsub("\n", "\\n")}\"" }.join(',') + "\r\n"
    end
  end

  def refresh_training_data(file_name, min_length = 20)
    shell_output = `wc -l #{file_name} | awk -F ' ' '{ print $1 }'`
    num_lines = shell_output.strip.to_i
    return unless num_lines >= min_length

    # Copy current training data to upload.csv, and clear current training data file.
    upload_file = 'out/training_data.csv'
    classifier_name = "topic"
    FileUtils.mv(file_name, upload_file)
    puts "-- uploading training set"
    WATSON_CLASSIFIER.upload(upload_file, classifier_name)
  end
end

CONFIG = YAML.load_file('config.yml')
TWITTER_CLIENT = TwitterClient.new(CONFIG['twitter']['oauth'])
WATSON_CLASSIFIER = Watson::Classifier.new(CONFIG['watson'])
SlackRealtimeClient.new(CONFIG['slack']['carebot']['api_token'])

## Streamer
A simple streaming script that watches a keyword on Twitter, pings the Watson Alchemy API for sentiment and automatically
replies to tweets when its confidence level is above a preset threshold. You can train this bot to categorize the topic of
a given tweet in a Slack channel of your organization.

## How to run it

1. Although MacOS ships with a Ruby version, it's too usually far too old for development purpose. Make sure you have the right Ruby version as specified in `.ruby-version`. If not, you can use [`rbenv`](https://github.com/rbenv/rbenv) to install 2.2.2.
1. `bundle install`
1. `cp config.yml.example config.yml`, and then fill in `config.yml` with your OAuth credentials.
1. `bundle exec ruby tweets.rb <your-keyword>`
1. To run the realtime Slack, `bundle exec ruby slack_realtime.rb`, and start talking to the bot in channel #training using `@carebot`.

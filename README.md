## Streamer
A simple streaming script that watches a keyword on Twitter, and does something when a new tweet becomes available.

## How to run it

1. Although MacOS ships with a Ruby version, it's too usually far too old for development purpose. Make sure you have the right Ruby version as specified in `.ruby-version`. If not, you can use [`rbenv`](https://github.com/rbenv/rbenv) to install 2.2.2.
1. `bundle install`
1. `bundle exec ruby tweets.rb <your-keyword>`

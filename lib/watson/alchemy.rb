require 'faraday'
require 'json'
require 'excon'

module Watson
  class Alchemy
    attr_accessor :conn
    def initialize(config)
      base_url = config['alchemy']['url']
      @api_key = config['alchemy']['api_key']

      @conn = Faraday.new(url: base_url) do |faraday|
        faraday.request :url_encoded
        faraday.adapter :excon
      end
    end

    def analyze(text)
      resp = @conn.post('', options.merge(text: text))
      JSON.parse(resp.body) if resp && resp.status == 200
    end

    def options
      { :apikey => @api_key,
        :extract => 'entities,doc-sentiment',
        :outputMode => 'json'
      }
    end
  end
end

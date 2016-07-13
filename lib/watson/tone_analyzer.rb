require 'faraday'
require 'json'

module Watson
  class ToneAnalyzer
    def initialize(config)
      base_url = config['tone_analyzer']['url']
      username = config['tone_analyzer']['username']
      password = config['tone_analyzer']['password']

      @conn ||= Faraday.new(url: base_url) do |faraday|
        faraday.headers['Content-Type'] = 'application/json'
        faraday.adapter Faraday.default_adapter
      end
      @conn.basic_auth(username, password)
    end

    def analyze(text)
      resp = @conn.post('', {:text => text}.to_json)
      JSON.parse(resp.body) if resp && resp.status == 200
    end

  end
end

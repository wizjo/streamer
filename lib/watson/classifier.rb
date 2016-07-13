require 'faraday'
require 'json'

module Watson
  class Classifier
    def initialize(config)
      base_url = config['language_classifier']['url']
      username = config['language_classifier']['username']
      password = config['language_classifier']['password']

      @conn = Faraday.new(url: base_url) do |faraday|
        faraday.request :multipart
        faraday.request :url_encoded

        faraday.response :logger
        faraday.adapter Faraday.default_adapter
      end
      @conn.basic_auth(username, password)
    end

    def upload(path_to_csv)
      payload = { training_data: Faraday::UploadIO.new(path_to_csv, 'text/csv'), training_metadata: {language: "en", name: "Care Classifier"}.to_json}
      resp = @conn.post('/natural-language-classifier/api/v1/classifiers', payload)
      @classifier = JSON.parse(resp.body) if resp && resp.status == 200
    end

    def list_classifiers()
      resp = @conn.get("natural-language-classifier/api/v1/classifiers");
      JSON.parse(resp.body) if resp && resp.status == 200
    end

    def classify(text, cid)
      if cid.nil?
        puts 'No classifier id found'
        exit 1
      end
      query = { text: text }
      resp = @conn.get("/natural-language-classifier/api/v1/classifiers/#{cid}/classify", query);
      JSON.parse(resp.body) if resp && resp.status == 200
    end
  end
end

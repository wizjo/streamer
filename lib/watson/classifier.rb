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
        faraday.adapter Faraday.default_adapter
      end
      @conn.basic_auth(username, password)
    end

    def upload(path_to_csv, classifier_name)
      payload = {
        training_data: Faraday::UploadIO.new(path_to_csv, 'text/plain'),
        training_metadata: { language: 'en', name: classifier_name }.to_json
      }
      puts payload.inspect
      resp = @conn.post('/natural-language-classifier/api/v1/classifiers', payload)
      classifier = JSON.parse(resp.body) if resp && resp.status == 200
      puts classifier.inspect
    end

    def list_classifiers
      resp = @conn.get("natural-language-classifier/api/v1/classifiers");
      JSON.parse(resp.body) if resp && resp.status == 200
    end

    def classifier_id_by_name(name)
      classifiers = list_classifiers
      classifier = classifiers && classifiers['classifiers'].sort_by{ |v| DateTime.parse(v['created']) }.find{ |v| v['name'] == name }
      classifier && classifier['classifier_id']
    end

    def classify(text, cid)
      resp = @conn.get("/natural-language-classifier/api/v1/classifiers/#{cid}/classify", { text: text });
      JSON.parse(resp.body) if resp && resp.status == 200
    end
  end
end

require "json"
require "net/http"
require "uri"

module IkeaWatch
  class Telegram
    Error = Class.new(StandardError)

    def initialize(token:, chat_id:)
      @token = token
      @chat_id = chat_id
    end

    def send_message(text)
      uri = URI("https://api.telegram.org/bot#{@token}/sendMessage")
      payload = { chat_id: @chat_id, text:, parse_mode: "HTML", disable_web_page_preview: true }

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 20) do |http|
        http.post(uri.path, JSON.generate(payload), "content-type" => "application/json")
      end
      return if response.is_a?(Net::HTTPSuccess)

      # Never include the URL in errors: it contains the bot token.
      description = JSON.parse(response.body)["description"] rescue nil
      raise Error, "Telegram returned HTTP #{response.code}: #{description}"
    end
  end
end

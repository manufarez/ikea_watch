require "json"
require "net/http"

module IkeaWatch
  class Telegram
    Error = Class.new(StandardError)

    def initialize(token:, chat_id:)
      @token = token
      @chat_id = chat_id
    end

    HOST = "api.telegram.org".freeze

    # Never include the request path in errors: it contains the bot token.
    def send_message(text)
      payload = { chat_id: @chat_id, text:, parse_mode: "HTML", disable_web_page_preview: true }

      response = Net::HTTP.start(HOST, 443, use_ssl: true, open_timeout: 10, read_timeout: 20) do |http|
        http.post("/bot#{@token}/sendMessage", JSON.generate(payload), "content-type" => "application/json")
      end
      return if response.is_a?(Net::HTTPSuccess)

      description = JSON.parse(response.body)["description"] rescue nil
      raise Error, "Telegram returned HTTP #{response.code}: #{description}"
    end
  end
end

require "json"
require "net/http"
require "uri"

module IkeaWatch
  # Fetches availability from IKEA's sales-item API (v2), the one ikea.com itself calls.
  class Client
    Error = Class.new(StandardError)

    ENDPOINT = "https://api.salesitem.ingka.com/availabilities/ru/mx".freeze
    EXPAND = "StoresList,Restocks,SalesLocations,DisplayLocations,ChildItems".freeze
    NETWORK_ERRORS = [IOError, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError].freeze

    def initialize(client_id:)
      @client_id = client_id
    end

    def fetch(item_nos)
      uri = URI(ENDPOINT)
      uri.query = URI.encode_www_form(itemNos: item_nos.join(","), expand: EXPAND)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 20) do |http|
        http.get(uri.request_uri, "accept" => "application/json;version=2", "x-client-id" => @client_id)
      end
      raise Error, "IKEA API returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      body = JSON.parse(response.body)
      raise Error, "IKEA API response has no 'availabilities' list" unless body["availabilities"].is_a?(Array)

      body
    rescue JSON::ParserError
      raise Error, "IKEA API returned invalid JSON"
    rescue *NETWORK_ERRORS => e
      raise Error, "IKEA API request failed: #{e.class}: #{e.message}"
    end
  end
end

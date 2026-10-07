module IkeaWatch
  ConfigError = Class.new(StandardError)

  # Known IKEA Mexico store codes (from ikea.com/mx/es/meta-data/informera/stores-detailed.json).
  STORE_NAMES = {
    "612" => "Oceanía",
    "652" => "Puebla",
    "683" => "Guadalajara Expo"
  }.freeze

  # Optional display names and product pages. Items not listed here fall back to a search URL.
  PRODUCTS = {
    "80600606" => {
      name: "DOFTAKLEJA duvet cover",
      url: "https://www.ikea.com/mx/es/p/doftakleja-funda-nordica-funda-s-de-almohada-azul-oscuro-cafe-claro-80600606/"
    }
  }.freeze

  DEFAULT_ITEM_NOS = "80600606".freeze
  DEFAULT_STORE_IDS = "612,652".freeze # Oceanía first, then Puebla
  DEFAULT_CLIENT_ID = "ef382663-a2a5-40d4-8afe-f0634821c0ed".freeze

  Config = Data.define(:item_nos, :stores, :client_id, :telegram_token, :telegram_chat_id, :state_path) do
    def self.from_env(env = ENV, state_path: File.expand_path("../../state.json", __dir__))
      new(
        item_nos: parse_item_nos(value(env, "ITEM_NOS", DEFAULT_ITEM_NOS)),
        stores: parse_stores(value(env, "STORE_IDS", DEFAULT_STORE_IDS)),
        client_id: value(env, "IKEA_CLIENT_ID", DEFAULT_CLIENT_ID),
        telegram_token: value(env, "TELEGRAM_BOT_TOKEN", nil),
        telegram_chat_id: value(env, "TELEGRAM_CHAT_ID", nil),
        state_path: state_path
      )
    end

    # Blank values count as unset, so an empty GitHub variable falls back to the default.
    def self.value(env, key, default)
      raw = env[key].to_s.strip
      raw.empty? ? default : raw
    end

    def self.parse_item_nos(raw)
      item_nos = raw.split(",").map { it.strip.delete(".") }.reject(&:empty?).uniq
      invalid = item_nos.grep_v(/\A\d{8}\z/)
      raise ConfigError, "Invalid item numbers in ITEM_NOS: #{invalid.join(", ")}" if invalid.any?
      raise ConfigError, "ITEM_NOS is empty" if item_nos.empty?

      item_nos
    end

    def self.parse_stores(raw)
      raw.split(",").map(&:strip).reject(&:empty?).to_h { [it, STORE_NAMES.fetch(it, "Store #{it}")] }
    end

    def telegram_configured?
      !telegram_token.nil? && !telegram_chat_id.nil?
    end

    # Describes a malformed token by its shape only, never its value.
    def validate_telegram!
      unless telegram_token.match?(/\A\d+:[\w-]+\z/)
        shape = "#{telegram_token.length} characters"
        shape += ", contains whitespace or line breaks" if telegram_token.match?(/\s/)
        raise ConfigError, "TELEGRAM_BOT_TOKEN does not look like a bot token (expected 123456:ABC..., got #{shape})"
      end
      return if telegram_chat_id.match?(/\A-?\d+\z/)

      raise ConfigError, "TELEGRAM_CHAT_ID should be a number (got #{telegram_chat_id.length} characters)"
    end
  end
end

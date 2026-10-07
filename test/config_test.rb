require_relative "test_helper"

class ConfigTest < Minitest::Test
  def test_defaults
    config = IkeaWatch::Config.from_env({})

    assert_equal ["80600606"], config.item_nos
    assert_equal({ "612" => "Oceanía", "652" => "Puebla" }, config.stores)
    assert_equal IkeaWatch::DEFAULT_CLIENT_ID, config.client_id
    refute config.telegram_configured?
  end

  def test_item_list_accepts_spaces_dots_and_blanks
    config = IkeaWatch::Config.from_env({ "ITEM_NOS" => " 806.006.06, 12345678,,", "IKEA_CLIENT_ID" => "" })

    assert_equal %w[80600606 12345678], config.item_nos
    assert_equal IkeaWatch::DEFAULT_CLIENT_ID, config.client_id
  end

  def test_valid_telegram_settings
    config = IkeaWatch::Config.from_env({ "TELEGRAM_BOT_TOKEN" => "123456:AA-b_c", "TELEGRAM_CHAT_ID" => "-100123" })

    assert config.validate_telegram!.nil?
  end

  def test_malformed_token_is_described_without_its_value
    token = "Use this token:\n123456:AAsecret"
    config = IkeaWatch::Config.from_env({ "TELEGRAM_BOT_TOKEN" => token, "TELEGRAM_CHAT_ID" => "42" })

    error = assert_raises(IkeaWatch::ConfigError) { config.validate_telegram! }
    assert_includes error.message, "#{token.length} characters, contains whitespace or line breaks"
    refute_includes error.message, "AAsecret"
  end

  def test_non_numeric_chat_id_is_rejected
    config = IkeaWatch::Config.from_env({ "TELEGRAM_BOT_TOKEN" => "123456:AA", "TELEGRAM_CHAT_ID" => "@me" })

    assert_raises(IkeaWatch::ConfigError) { config.validate_telegram! }
  end

  def test_heartbeat_hour
    assert_equal 9, IkeaWatch::Config.from_env({}).heartbeat_hour
    assert_equal 18, IkeaWatch::Config.from_env({ "HEARTBEAT_HOUR" => "18" }).heartbeat_hour
    assert_nil IkeaWatch::Config.from_env({ "HEARTBEAT_HOUR" => "off" }).heartbeat_hour
    assert_raises(IkeaWatch::ConfigError) { IkeaWatch::Config.from_env({ "HEARTBEAT_HOUR" => "25" }) }
  end

  def test_rejects_invalid_item_numbers
    error = assert_raises(IkeaWatch::ConfigError) { IkeaWatch::Config.from_env({ "ITEM_NOS" => "80600606,abc" }) }
    assert_includes error.message, "abc"
  end
end

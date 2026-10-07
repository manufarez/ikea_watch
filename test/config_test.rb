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

  def test_rejects_invalid_item_numbers
    error = assert_raises(IkeaWatch::ConfigError) { IkeaWatch::Config.from_env({ "ITEM_NOS" => "80600606,abc" }) }
    assert_includes error.message, "abc"
  end
end

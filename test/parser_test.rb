require_relative "test_helper"

class ParserTest < Minitest::Test
  def setup
    @item = Fixtures.sample_snapshot.fetch("80600606")
  end

  def test_not_buyable_online_even_though_delivery_range_is_true
    refute @item["online_buyable"]
    assert_equal "OUT_OF_STOCK", @item["online_probability"]
    assert_nil @item["online_restock_date"]
  end

  def test_store_quantities_and_probabilities
    assert_equal(
      { "name" => "Oceanía", "quantity" => 1, "probability" => "MEDIUM_IN_STOCK", "restock_date" => nil },
      @item["stores"]["612"]
    )
    assert_equal(
      { "name" => "Puebla", "quantity" => 5, "probability" => "HIGH_IN_STOCK", "restock_date" => nil },
      @item["stores"]["652"]
    )
  end

  def test_tracks_only_configured_stores_in_order
    assert_equal %w[612 652], @item["stores"].keys
  end

  def test_other_stores_parse_from_the_same_response
    item = IkeaWatch::Parser.call(Fixtures.sample_response, item_nos: ["80600606"], stores: { "683" => "Guadalajara Expo" })

    assert_equal 0, item.dig("80600606", "stores", "683", "quantity")
    assert_equal "OUT_OF_STOCK", item.dig("80600606", "stores", "683", "probability")
  end

  def test_store_missing_from_response_is_not_listed
    item = IkeaWatch::Parser.call(Fixtures.sample_response, item_nos: ["80600606"], stores: { "999" => "Nowhere" })

    assert_equal({ "name" => "Nowhere", "quantity" => nil, "probability" => nil, "restock_date" => nil },
                 item.dig("80600606", "stores", "999"))
  end

  def test_item_missing_from_response_is_skipped
    items = IkeaWatch::Parser.call(Fixtures.sample_response, item_nos: %w[80600606 12345678], stores: Fixtures::STORES)

    assert_equal ["80600606"], items.keys
  end

  def test_online_buyable_when_home_delivery_available
    response = Fixtures.sample_response
    online_entry(response)["availableForHomeDelivery"] = true

    assert IkeaWatch::Parser.call(response, item_nos: ["80600606"], stores: {}).dig("80600606", "online_buyable")
  end

  def test_restock_date_takes_earliest_date
    response = Fixtures.sample_response
    oceania = response["availabilities"].find { it.dig("classUnitKey", "classUnitCode") == "612" }
    oceania["buyingOption"]["cashCarry"]["availability"]["restocks"] = [
      { "earliestDate" => "2026-11-02", "latestDate" => "2026-11-09", "quantity" => 10 },
      { "earliestDate" => "2026-10-20", "latestDate" => "2026-10-27", "quantity" => 4 }
    ]

    item = IkeaWatch::Parser.call(response, item_nos: ["80600606"], stores: Fixtures::STORES)
    assert_equal "2026-10-20", item.dig("80600606", "stores", "612", "restock_date")
  end

  def test_online_restock_date
    response = Fixtures.sample_response
    online_entry(response)["buyingOption"]["homeDelivery"]["availability"]["restocks"] = [{ "date" => "2026-10-15T00:00:00Z" }]

    item = IkeaWatch::Parser.call(response, item_nos: ["80600606"], stores: {})
    assert_equal "2026-10-15", item.dig("80600606", "online_restock_date")
  end

  private

  def online_entry(response)
    response["availabilities"].find { it.dig("classUnitKey", "classUnitType") == "RU" }
  end
end

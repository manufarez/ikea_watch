module IkeaWatch
  # Turns a raw API response into the normalized snapshot stored in state.json:
  #
  #   { "80600606" => { "online_buyable" => false, "online_probability" => "OUT_OF_STOCK",
  #                     "online_restock_date" => nil,
  #                     "stores" => { "612" => { "name" => "Oceanía", "quantity" => 1,
  #                                              "probability" => "MEDIUM_IN_STOCK", "restock_date" => nil } } } }
  #
  # The API returns one entry per location. The "RU"/"MX" entry is online sales for the whole country.
  # Its availableForHomeDelivery flag is what drives "Agotado en línea" on ikea.com, while
  # homeDelivery.range.inRange only says the item is in the deliverable range (true even when sold out).
  module Parser
    ONLINE_UNIT = "RU".freeze
    STORE_UNIT = "STO".freeze

    module_function

    def call(response, item_nos:, stores:)
      entries = response.fetch("availabilities")

      item_nos.each_with_object({}) do |item_no, items|
        mine = entries.select { it.dig("itemKey", "itemNo") == item_no }
        next if mine.empty?

        warn_unless_article(item_no, mine)
        items[item_no] = item_snapshot(mine, stores)
      end
    end

    def item_snapshot(entries, stores)
      online = entries.find { it.dig("classUnitKey", "classUnitType") == ONLINE_UNIT }
      delivery = online&.dig("buyingOption", "homeDelivery")

      {
        "online_buyable" => online&.dig("availableForHomeDelivery") == true,
        "online_probability" => probability(delivery),
        "online_restock_date" => restock_date(delivery),
        "stores" => stores.to_h { |id, name| [id, store_snapshot(store_entry(entries, id), name)] }
      }
    end

    def store_entry(entries, store_id)
      entries.find do
        it.dig("classUnitKey", "classUnitType") == STORE_UNIT && it.dig("classUnitKey", "classUnitCode") == store_id
      end
    end

    # A store missing from the response is recorded with nil values ("not listed").
    def store_snapshot(entry, name)
      cash_carry = entry&.dig("buyingOption", "cashCarry")

      {
        "name" => name,
        "quantity" => cash_carry&.dig("availability", "quantity"),
        "probability" => probability(cash_carry),
        "restock_date" => restock_date(cash_carry)
      }
    end

    def probability(buying_option)
      buying_option&.dig("availability", "probability", "thisDay", "messageType")
    end

    # The sample response carries no restock data, so its exact shape is unconfirmed.
    # Look for a "restocks" list on the buying option or its availability and keep the earliest date.
    def restock_date(buying_option)
      return nil unless buying_option

      restocks = [buying_option["restocks"], buying_option.dig("availability", "restocks")].compact.flatten
      dates = restocks.filter_map { it.is_a?(Hash) && (it["earliestDate"] || it["date"] || it["latestDate"]) }
      warn "Unrecognized restock data: #{restocks.inspect}" if restocks.any? && dates.empty?

      dates.map { it.to_s[0, 10] }.min
    end

    def warn_unless_article(item_no, entries)
      types = entries.map { it.dig("itemKey", "itemType") }.uniq
      return if types == ["ART"]

      warn "Item #{item_no} has type #{types.join("/")}, not a single article (ART); only its own availability is tracked"
    end
  end
end

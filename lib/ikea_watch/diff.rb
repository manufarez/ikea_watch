module IkeaWatch
  RESTOCK_FIELDS = %w[online_restock_date restock_date].freeze

  # One field that changed between two snapshots. store_id is nil for online fields.
  Change = Data.define(:item_no, :store_id, :store_name, :field, :before, :after) do
    # Priority changes are highlighted at the top of the Telegram message.
    def priority?
      became_buyable_online? || restock_announced?
    end

    def became_buyable_online?
      field == "online_buyable" && after == true
    end

    def restock_announced?
      RESTOCK_FIELDS.include?(field) && before.nil? && !after.nil?
    end
  end

  module Diff
    ONLINE_FIELDS = %w[online_buyable online_probability online_restock_date].freeze
    STORE_FIELDS = %w[quantity probability restock_date].freeze

    module_function

    # Only items present in both snapshots are compared; newly watched items are reported separately.
    def call(previous, current)
      current.flat_map do |item_no, now|
        before = previous[item_no]
        before ? item_changes(item_no, before, now) : []
      end
    end

    def item_changes(item_no, before, now)
      online = ONLINE_FIELDS.filter_map do |field|
        change(item_no, nil, nil, field, before[field], now[field])
      end

      stores = now.fetch("stores").flat_map do |store_id, store|
        old_store = before.dig("stores", store_id) || {}
        STORE_FIELDS.filter_map do |field|
          change(item_no, store_id, store["name"], field, old_store[field], store[field])
        end
      end

      online + stores
    end

    def change(item_no, store_id, store_name, field, before, after)
      return if before == after

      Change.new(item_no:, store_id:, store_name:, field:, before:, after:)
    end
  end
end

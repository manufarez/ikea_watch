module IkeaWatch
  # Builds Telegram messages (HTML parse mode).
  module Message
    PROBABILITY_LABELS = {
      "HIGH_IN_STOCK" => "high stock",
      "MEDIUM_IN_STOCK" => "medium stock",
      "LOW_IN_STOCK" => "low stock",
      "OUT_OF_STOCK" => "out of stock"
    }.freeze

    FIELD_LABELS = {
      "online_buyable" => "Buyable online",
      "online_probability" => "Online stock",
      "online_restock_date" => "Online restock",
      "quantity" => "quantity",
      "probability" => "stock level",
      "restock_date" => "restock"
    }.freeze

    module_function

    def changes(changes)
      highlights = changes.select(&:priority?).map { "🚨 <b>#{highlight(it)}</b>" }

      details = changes.group_by(&:item_no).map do |item_no, item_changes|
        lines = item_changes.map { "• #{change_line(it)}" }
        [item_heading(item_no), *lines, product_url(item_no)].join("\n")
      end

      [highlights.join("\n").then { it.empty? ? nil : it }, *details].compact.join("\n\n")
    end

    def started(items)
      items.map { |item_no, item| "👀 Now watching\n#{item_summary(item_no, item)}" }.join("\n\n")
    end

    def heartbeat(items, stats)
      header = ["💓 <b>Daily check-in: still watching</b>", *run_stats(stats)].join("\n")
      [header, *items.map { |item_no, item| item_summary(item_no, item) }].join("\n\n")
    end

    def run_stats(stats)
      return ["Schedule stats unavailable (only computed on GitHub Actions)"] unless stats
      return ["No scheduled runs in the last 24 h"] if stats.count.zero?

      [
        "Scheduled runs in the last 24 h: #{stats.count} of #{stats.expected}",
        "Start delay after :00/:30: #{stats.average_delay} min on average, #{stats.max_delay} min at most",
        "Longest gap between runs: #{duration(stats.longest_gap)}"
      ]
    end

    def item_summary(item_no, item)
      lines = ["• Online: #{yes_no(item["online_buyable"])} (#{probability(item["online_probability"])})"]
      lines += item["stores"].values.map do |store|
        "• #{escape(store["name"])}: #{quantity(store["quantity"])} (#{probability(store["probability"])})"
      end
      [item_heading(item_no), *lines, product_url(item_no)].join("\n")
    end

    def duration(minutes)
      hours, mins = minutes.divmod(60)
      hours.zero? ? "#{mins} min" : "#{hours} h #{mins.to_s.rjust(2, "0")} min"
    end

    def outage(failures, error)
      "⚠️ <b>IKEA monitoring is not working</b>\n" \
        "The availability check failed #{failures} times in a row.\n" \
        "Last error: #{escape(error)}"
    end

    def recovered(failures)
      "✅ <b>IKEA monitoring is working again</b> (after #{failures} failed checks)"
    end

    def highlight(change)
      name = escape(product_name(change.item_no))
      if change.became_buyable_online?
        "#{name} is now buyable online!"
      elsif change.store_id
        "Restock date announced for #{name} at #{escape(change.store_name)}: #{change.after}"
      else
        "Online restock date announced for #{name}: #{change.after}"
      end
    end

    def change_line(change)
      label = FIELD_LABELS.fetch(change.field)
      label = "#{escape(change.store_name)} #{label}" if change.store_id
      "#{label}: #{format_value(change.field, change.before)} → <b>#{format_value(change.field, change.after)}</b>"
    end

    def format_value(field, value)
      case field
      when "online_buyable" then yes_no(value)
      when "quantity" then quantity(value)
      when /probability/ then probability(value)
      else value || "none"
      end
    end

    def yes_no(value) = value ? "yes" : "no"

    def quantity(value) = value.nil? ? "not listed" : value.to_s

    def probability(value)
      return "unknown" if value.nil?

      PROBABILITY_LABELS.fetch(value) { value.downcase.tr("_", " ") }
    end

    def item_heading(item_no)
      "📦 <b>#{escape(product_name(item_no))}</b> (#{formatted_item_no(item_no)})"
    end

    def product_name(item_no)
      PRODUCTS.dig(item_no, :name) || "Item #{formatted_item_no(item_no)}"
    end

    def product_url(item_no)
      PRODUCTS.dig(item_no, :url) || "https://www.ikea.com/mx/es/search/?q=#{item_no}"
    end

    # IKEA displays article numbers as 806.006.06.
    def formatted_item_no(item_no)
      item_no.sub(/\A(\d{3})(\d{3})(\d{2})\z/, '\1.\2.\3')
    end

    def escape(text)
      text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    end
  end
end

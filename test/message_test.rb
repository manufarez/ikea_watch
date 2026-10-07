require_relative "test_helper"

class MessageTest < Minitest::Test
  def test_changes_lists_before_and_after_with_link
    current = Fixtures.modified_snapshot do
      it["stores"]["612"]["quantity"] = 0
      it["stores"]["612"]["probability"] = "OUT_OF_STOCK"
    end
    text = IkeaWatch::Message.changes(IkeaWatch::Diff.call(Fixtures.sample_snapshot, current))

    assert_includes text, "📦 <b>DOFTAKLEJA duvet cover</b> (806.006.06)"
    assert_includes text, "• Oceanía quantity: 1 → <b>0</b>"
    assert_includes text, "• Oceanía stock level: medium stock → <b>out of stock</b>"
    assert_includes text, IkeaWatch::PRODUCTS.dig("80600606", :url)
    refute_includes text, "🚨"
  end

  def test_priority_changes_are_highlighted_first
    current = Fixtures.modified_snapshot do
      it["stores"]["652"]["quantity"] = 4
      it["online_buyable"] = true
      it["stores"]["612"]["restock_date"] = "2026-10-20"
    end
    text = IkeaWatch::Message.changes(IkeaWatch::Diff.call(Fixtures.sample_snapshot, current))

    assert text.start_with?(
      "🚨 <b>DOFTAKLEJA duvet cover is now buyable online!</b>\n" \
      "🚨 <b>Restock date announced for DOFTAKLEJA duvet cover at Oceanía: 2026-10-20</b>\n\n"
    )
    assert_includes text, "• Buyable online: no → <b>yes</b>"
    assert_includes text, "• Oceanía restock: none → <b>2026-10-20</b>"
  end

  def test_started_summarizes_current_state
    text = IkeaWatch::Message.started(Fixtures.sample_snapshot)

    assert_includes text, "👀 Now watching"
    assert_includes text, "• Online: no (out of stock)"
    assert_includes text, "• Oceanía: 1 (medium stock)"
    assert_includes text, "• Puebla: 5 (high stock)"
  end

  def test_unknown_item_falls_back_to_search_url
    assert_equal "Item 123.456.78", IkeaWatch::Message.product_name("12345678")
    assert_equal "https://www.ikea.com/mx/es/search/?q=12345678", IkeaWatch::Message.product_url("12345678")
  end

  def test_outage_escapes_error_text
    assert_includes IkeaWatch::Message.outage(3, "HTTP <503>"), "HTTP &lt;503&gt;"
  end
end

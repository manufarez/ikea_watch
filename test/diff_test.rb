require_relative "test_helper"

class DiffTest < Minitest::Test
  def setup
    @previous = Fixtures.sample_snapshot
  end

  def test_identical_snapshots_have_no_changes
    assert_empty IkeaWatch::Diff.call(@previous, Fixtures.sample_snapshot)
  end

  def test_store_quantity_change
    current = Fixtures.modified_snapshot { it["stores"]["612"]["quantity"] = 0 }

    change = only(IkeaWatch::Diff.call(@previous, current))
    assert_equal ["612", "Oceanía", "quantity", 1, 0], [change.store_id, change.store_name, change.field, change.before, change.after]
    refute change.priority?
  end

  def test_becoming_buyable_online_is_a_priority
    current = Fixtures.modified_snapshot do
      it["online_buyable"] = true
      it["online_probability"] = "HIGH_IN_STOCK"
    end

    changes = IkeaWatch::Diff.call(@previous, current)
    assert_equal %w[online_buyable online_probability], changes.map(&:field)
    assert changes.first.became_buyable_online?
    refute changes.last.priority?
  end

  def test_becoming_unbuyable_online_is_not_a_priority
    previous = Fixtures.modified_snapshot { it["online_buyable"] = true }

    refute only(IkeaWatch::Diff.call(previous, Fixtures.sample_snapshot)).priority?
  end

  def test_new_restock_date_is_a_priority
    current = Fixtures.modified_snapshot { it["stores"]["652"]["restock_date"] = "2026-10-20" }

    change = only(IkeaWatch::Diff.call(@previous, current))
    assert change.restock_announced?
  end

  def test_moved_restock_date_is_not_a_priority
    previous = Fixtures.modified_snapshot { it["online_restock_date"] = "2026-10-20" }
    current = Fixtures.modified_snapshot { it["online_restock_date"] = "2026-10-27" }

    refute only(IkeaWatch::Diff.call(previous, current)).priority?
  end

  def test_newly_watched_item_is_not_diffed
    assert_empty IkeaWatch::Diff.call({}, Fixtures.sample_snapshot)
  end

  def test_newly_watched_store_is_diffed_against_nothing
    previous = Fixtures.modified_snapshot { it["stores"].delete("652") }

    fields = IkeaWatch::Diff.call(previous, Fixtures.sample_snapshot).map(&:field)
    assert_equal %w[quantity probability], fields
  end
end

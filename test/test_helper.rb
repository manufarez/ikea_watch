require "minitest/autorun"
require "json"
require "tmpdir"
require_relative "../lib/ikea_watch"

module Fixtures
  STORES = { "612" => "Oceanía", "652" => "Puebla" }.freeze

  module_function

  def sample_response
    JSON.parse(File.read(File.expand_path("../fixtures/sample.json", __dir__)))
  end

  def sample_snapshot
    IkeaWatch::Parser.call(sample_response, item_nos: ["80600606"], stores: STORES)
  end

  # Deep copy of the sample snapshot, adjusted by the block.
  def modified_snapshot
    JSON.parse(JSON.generate(sample_snapshot)).tap { yield it["80600606"] }
  end
end

class Minitest::Test
  # Asserts the list has exactly one element and returns it.
  def only(list)
    assert_equal 1, list.size, "expected exactly one element, got #{list.inspect}"
    list.first
  end
end

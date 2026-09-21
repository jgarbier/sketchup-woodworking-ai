require 'minitest/autorun'
require_relative '../woodworking_ai/geometry'
class UnitsTest < Minitest::Test
  def test_inches_remain_inches
    assert_equal 48.0, WoodworkingAI::Units.number(48, 'length', positive: true)
    assert_equal [-2.0, 0.0, 3.5], WoodworkingAI::Units.position(x: -2, y: 0, z: 3.5)
  end
  def test_invalid_dimensions
    [0, -1, Float::NAN, Float::INFINITY, '48', nil].each do |value|
      assert_raises(ArgumentError) { WoodworkingAI::Units.number(value, 'length', positive: true) }
    end
  end
  def test_incomplete_or_extra_coordinates
    [{x: 0}, {x: 0, y: 0, z: 0, unit: 'mm'}, nil].each do |value|
      assert_raises(ArgumentError) { WoodworkingAI::Units.position(value) }
    end
  end
  def test_stable_identifiers
    assert_equal 'top-1', WoodworkingAI.identifier('top-1', 'id')
    ['', '../top', 'top with spaces', nil].each do |value|
      assert_raises(ArgumentError) { WoodworkingAI.identifier(value, 'id') }
    end
  end
  def test_invalid_input_fails_before_sketchup_access
    assert_raises(ArgumentError) do
      WoodworkingAI.create_board(id: 'top', name: 'Top', length: -1, width: 18,
        thickness: 1, position: {x: 0, y: 0, z: 0})
    end
  end
end

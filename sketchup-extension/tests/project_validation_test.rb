require 'minitest/autorun'
require_relative '../woodworking_ai/project_validation'
class ProjectValidationTest < Minitest::Test
  def example
    JSON.parse(File.read(File.expand_path('../../schema/example-bench.json', __dir__)))
  end
  def test_accepts_canonical_project
    assert_equal 'inches', WoodworkingAI::ProjectValidation.validate(example)['project']['units']
  end
  def test_rejects_bad_semantics
    project = example
    project['parts'] << project['parts'][0]
    assert_raises(ArgumentError) { WoodworkingAI::ProjectValidation.validate(project) }
    project = example
    project['parts'][0]['quantity'] = 2
    assert_raises(ArgumentError) { WoodworkingAI::ProjectValidation.validate(project) }
    project = example
    project['parts'][0]['material'] = 'unknown'
    assert_raises(ArgumentError) { WoodworkingAI::ProjectValidation.validate(project) }
  end
  def test_rejects_bad_units_and_dimensions
    project = example
    project['project']['units'] = 'mm'
    assert_raises(ArgumentError) { WoodworkingAI::ProjectValidation.validate(project) }
    project = example
    project['parts'][0]['dimensions']['length'] = -1
    assert_raises(ArgumentError) { WoodworkingAI::ProjectValidation.validate(project) }
  end
end

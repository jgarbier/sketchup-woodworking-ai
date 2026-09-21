require 'minitest/autorun'
require 'tmpdir'
require_relative '../woodworking_ai/projects'
module Sketchup
  class ComponentInstance; end
  def self.active_model; end
end
class FakeModel
  attr_reader :aborted, :committed, :attributes
  def initialize
    @attributes = {}
  end
  def active_path; nil; end
  def entities; []; end
  def get_attribute(dict, id); @attributes[[dict,id]]; end
  def set_attribute(dict,id,value); @attributes[[dict,id]]=value; end
  def start_operation(*args); @before=@attributes.dup; end
  def abort_operation; @attributes=@before; @aborted=true; end
  def commit_operation; @committed=true; end
end
class ProjectTransactionTest < Minitest::Test
  def test_geometry_failure_rolls_back_model_and_files
    project=JSON.parse(File.read(File.expand_path('../../schema/example-bench.json', __dir__)))
    model=FakeModel.new
    Dir.mktmpdir do |dir|
      root=WoodworkingAI::Projects::ROOT
      WoodworkingAI::Projects.send(:remove_const, :ROOT)
      WoodworkingAI::Projects.const_set(:ROOT, dir)
      begin
        fail_geometry=lambda do |**args|
          assert File.exist?(File.join(dir,project['project']['id'],'project.yaml')), 'Definition is saved before geometry'
          raise 'simulated geometry failure'
        end
        Sketchup.stub(:active_model,model) do
          WoodworkingAI.stub(:create_board,fail_geometry) do
            assert_raises(RuntimeError) { WoodworkingAI::Projects.apply(project,nil) }
          end
        end
        assert model.aborted
        refute model.committed
        assert_empty model.attributes
        refute File.exist?(File.join(dir,project['project']['id'],'project.yaml'))
        refute File.exist?(File.join(dir,project['project']['id'],'state.json'))
      ensure
        WoodworkingAI::Projects.send(:remove_const, :ROOT)
        WoodworkingAI::Projects.const_set(:ROOT, root)
      end
    end
  end
  def test_stale_revision_rejected_before_geometry
    model=FakeModel.new
    project=JSON.parse(File.read(File.expand_path('../../schema/example-bench.json', __dir__)))
    Sketchup.stub(:active_model,model) do
      assert_raises(ArgumentError) { WoodworkingAI::Projects.apply(project,'stale') }
      refute model.committed
      refute model.aborted
    end
  end
end

require 'minitest/autorun'
require 'tmpdir'
require_relative '../woodworking_ai/exporter'
module Sketchup
  def self.active_model; end
end
class SaveModelTest < Minitest::Test
  def test_untitled_model_uses_save_and_existing_model_uses_save_copy
    ['', '/existing/user-model.skp'].each do |existing_path|
      model=Object.new
      calls=[]
      model.define_singleton_method(:path) { existing_path }
      model.define_singleton_method(:save) { |path| calls << [:save,path]; true }
      model.define_singleton_method(:save_copy) { |path| calls << [:save_copy,path]; true }
      Dir.mktmpdir do |dir|
        Sketchup.stub(:active_model,model) do
          WoodworkingAI::Projects.stub(:path,dir) do
            assert_equal File.join(dir,'bench.skp'),WoodworkingAI::Exporter.save_model('test')
          end
        end
        assert_equal existing_path.empty? ? :save : :save_copy,calls.first.first
        assert_equal 1,calls.length
      end
    end
  end
end

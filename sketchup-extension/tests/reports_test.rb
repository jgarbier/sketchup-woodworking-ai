require 'minitest/autorun'
require 'json'
require_relative '../woodworking_ai/reports'
class ReportsTest < Minitest::Test
  def project
    {'project'=>{'name'=>'Test'},'overall'=>{'width'=>48,'depth'=>18,'height'=>1},'materials'=>[{'id'=>'oak','species'=>'oak','type'=>'hardwood'}],
     'parts'=>[{'id'=>'top','name'=>'Top','material'=>'oak','stock_type'=>'hardwood','quantity'=>2,
       'dimensions'=>{'length'=>48,'width'=>18,'thickness'=>1},'grain_direction'=>'length','position'=>{'x'=>0,'y'=>0,'z'=>0},'rotation'=>{'x'=>0,'y'=>0,'z'=>0},'notes'=>[]}],
     'relationships'=>[],'notes'=>[]}
  end
  def test_cut_list_is_local_dimensions_and_quantity
    row=CSV.parse(WoodworkingAI::Reports.cut_list(project),headers:true).first
    assert_equal '2',row['quantity']
    assert_equal '48',row['length']
    assert_equal '18',row['width']
  end
  def test_bom_exact_volume_without_waste
    row=CSV.parse(WoodworkingAI::Reports.bom(project),headers:true).first
    assert_equal 1728, row['net_cubic_inches'].to_f
    assert_equal 12, row['net_board_feet'].to_f
    assert_equal '', row['net_square_feet'].to_s
  end
  def test_sheet_goods_use_area
    p=project;p['parts'][0]['stock_type']='plywood'
    row=CSV.parse(WoodworkingAI::Reports.bom(p),headers:true).first
    assert_equal 12,row['net_square_feet'].to_f
    assert_equal '',row['net_board_feet'].to_s
  end
  def test_csv_escaping_and_spreadsheet_formula_protection
    p=project;p['parts'][0]['name']='=1+1,"quoted"'
    row=CSV.parse(WoodworkingAI::Reports.cut_list(p),headers:true).first
    assert_equal "'=1+1,\"quoted\"", row['part']
  end
  def test_plan_contains_deliverables_and_assumptions
    plan=WoodworkingAI::Reports.build_plan(project)
    %w[Materials Parts Assumptions bench.skp renders/exploded.png].each { |text| assert_includes plan,text }
  end
end

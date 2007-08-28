require 'test_helper'

require 'text_mate_mock'
require 'rails/rails_path'

TextMate.line_number = '1'
TextMate.column_number = '1'
TextMate.project_directory = File.dirname(__FILE__) + '/fixtures'

class RailsPathTest < Test::Unit::TestCase
  def setup
    @rp_controller = RailsPath.new(FIXTURE_PATH + '/app/controllers/user_controller.rb')
    @rp_controller_with_module = RailsPath.new(FIXTURE_PATH + '/app/controllers/admin/base_controller.rb')
    @rp_view = RailsPath.new(FIXTURE_PATH + '/app/views/user/new.rhtml')
    @rp_view_with_module = RailsPath.new(FIXTURE_PATH + '/app/views/admin/base/action.rhtml')
  end
  
  def test_rails_root
    assert_equal File.dirname(__FILE__) + '/fixtures', RailsPath.new.rails_root
  end
  
  def test_extension
    assert_equal "rb", @rp_controller.extension
    assert_equal "rhtml", @rp_view.extension
  end

  def test_file_type
    assert_equal :controller, @rp_controller.file_type
    assert_equal :view, @rp_view.file_type
  end
  
  def test_modules
    assert_equal [], @rp_controller.modules
    assert_equal ['admin'], @rp_controller_with_module.modules
    assert_equal [], @rp_view.modules
    assert_equal ['admin'], @rp_view_with_module.modules
  end
  
  def test_controller_name_and_action_name_for_controller
    rp = RailsPath.new(FIXTURE_PATH + '/app/controllers/user_controller.rb')
    assert_equal "user", rp.controller_name
    assert_equal nil, rp.action_name

    TextMate.line_number = '3'
    rp = RailsPath.new(FIXTURE_PATH + '/app/controllers/user_controller.rb')
    assert_equal "user", rp.controller_name
    assert_equal "new", rp.action_name

    TextMate.line_number = '6'
    rp = RailsPath.new(FIXTURE_PATH + '/app/controllers/user_controller.rb')
    assert_equal "user", rp.controller_name
    assert_equal "create", rp.action_name
  end

  def test_controller_name_and_action_name_for_view
    rp = RailsPath.new(FIXTURE_PATH + '/app/views/user/new.rhtml')
    assert_equal "user", rp.controller_name
    assert_equal "new", rp.action_name
  end
  
  def test_rails_path_for
    partners = [
      # Basic tests
      [FIXTURE_PATH + '/app/controllers/user_controller.rb', :helper, FIXTURE_PATH + '/app/helpers/user_helper.rb'],
      [FIXTURE_PATH + '/app/controllers/user_controller.rb', :javascript, FIXTURE_PATH + '/public/javascripts/user.js'],
      [FIXTURE_PATH + '/app/controllers/user_controller.rb', :functional_test, FIXTURE_PATH + '/test/functional/user_controller_test.rb'],
      [FIXTURE_PATH + '/app/helpers/user_helper.rb', :controller, FIXTURE_PATH + '/app/controllers/user_controller.rb'],
      # With modules
      [FIXTURE_PATH + '/app/controllers/admin/base_controller.rb', :helper, FIXTURE_PATH + '/app/helpers/admin/base_helper.rb'],
      [FIXTURE_PATH + '/app/controllers/admin/inside/outside_controller.rb', :javascript, FIXTURE_PATH + '/public/javascripts/admin/inside/outside.js'],
      [FIXTURE_PATH + '/app/controllers/admin/base_controller.rb', :functional_test, FIXTURE_PATH + '/test/functional/admin/base_controller_test.rb'],
      [FIXTURE_PATH + '/app/helpers/admin/base_helper.rb', :controller, FIXTURE_PATH + '/app/controllers/admin/base_controller.rb']
    ]
    for pair in partners
      assert_equal RailsPath.new(pair[2]), RailsPath.new(pair[0]).rails_path_for(pair[1])
    end
    
    # Test controller to view
    TextMate.line_number = '6'
    current_file = RailsPath.new(FIXTURE_PATH + '/app/controllers/user_controller.rb')
    assert_equal RailsPath.new(FIXTURE_PATH + '/app/views/user/create.rhtml'), current_file.rails_path_for(:view)

    TextMate.line_number = '3'
    current_file = RailsPath.new(FIXTURE_PATH + '/app/controllers/user_controller.rb')
    assert_equal RailsPath.new(FIXTURE_PATH + '/app/views/user/new.rhtml'), current_file.rails_path_for(:view)
    
    # Test view to controller
    current_file = RailsPath.new(FIXTURE_PATH + '/app/views/user/new.rhtml')
    assert_equal RailsPath.new(FIXTURE_PATH + '/app/controllers/user_controller.rb'), current_file.rails_path_for(:controller)
  end
end
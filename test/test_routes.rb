require File.dirname(__FILE__) + '/helper'
require 'json'

class RoutesTest < Test::Unit::TestCase

  test "defines OPTIONS request handlers with options" do
    mock_app {
      register Sinatra::REST::Routes
      options '/hello' do
        response['X-Hello'] = 'World!'
        'remove me'
      end
    }
  
    request = Rack::MockRequest.new(@app)
    response = request.request("OPTIONS", '/hello', {})
    assert response.ok?
    assert_equal 'World!', response.headers['X-Hello']
    assert_equal 'remove me', response.body
  end
  
  context "route option :allow" do
    test "should return 403 if the proc returns false" do
      mock_app {
        register Sinatra::REST::Routes
        helpers do
          def credentials; ["nobody"]; end
        end
        get '/', :allow => lambda{|credentials| credentials.first == "crohr" } do
          "allowed"
        end
      }
      get '/'
      assert_equal 403, last_response.status
      assert_equal "You cannot access this resource", last_response.body
    end
    test "should return 200 if the proc returns true" do
      mock_app {
        register Sinatra::REST::Routes
        helpers do
          def credentials; ["crohr", "1234x"]; end
        end
        get '/', :allow => lambda{|credentials| credentials.first == "crohr" && credentials.last == "1234x" } do
          "allowed"
        end
      }
      get '/'
      assert_equal 200, last_response.status
      assert_equal "allowed", last_response.body
    end
    test "should raise an error if the argument is not a proc" do
      assert_raise(ArgumentError) {
        mock_app {
          register Sinatra::REST::Routes
          get '/', :allow => :whatever do
            "allowed"
          end
        }
      }
    end
    test "should raise a NoMethodError if 'credentials' helpers are not defined" do
      mock_app {
        register Sinatra::REST::Routes
        get '/', :allow => lambda{} do
          "allowed"
        end
      }
      assert_raise(NameError) { get '/' }
    end
  end
end
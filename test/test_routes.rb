require File.dirname(__FILE__) + '/helper'
require 'sinatra/rest/routes'

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
  
end
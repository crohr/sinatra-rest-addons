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
  
  context "route option :provides" do
  
    test "should return 406 and the list of supported types, if the server does not support the types accepted by the client [simple matching]" do
      mock_app {
        register Sinatra::REST::Routes
        get '/', :provides => ["application/xml", "application/vnd.x.y.z+xml"] do
          request.env['HTTP_ACCEPT']
        end
      }
      get '/', {}, { 'HTTP_ACCEPT' => 'application/json' }
      assert_equal 406, last_response.status
      assert_equal 'application/xml,application/vnd.x.y.z+xml', last_response.body
      assert_equal 'text/plain', last_response.headers['Content-Type']
    end
    test "should return 406 if the accepted type has a level lower than what is supported" do
      mock_app {
        register Sinatra::REST::Routes
        get '/', :provides => ["application/xml;level=5"] do
          request.env['HTTP_ACCEPT']
        end
      }
      get '/', {}, { 'HTTP_ACCEPT' => 'application/xml;level=4' }
      assert_equal 406, last_response.status
      assert_equal 'application/xml;level=5', last_response.body
      assert_equal 'text/plain', last_response.headers['Content-Type']
    end
    test "should return the first matching type if the accepted type contains a *" do
      mock_app {
        register Sinatra::REST::Routes
        get '/', :provides => ["application/xml", "application/vnd.x.y.z+xml"] do
          request.env['HTTP_ACCEPT']
        end
      }
      get '/', {}, { 'HTTP_ACCEPT' => 'application/*' }
      assert_equal 200, last_response.status
      assert_equal 'application/*', last_response.body
      assert_equal 'application/xml', last_response.headers['Content-Type']
    end
    test "should respect the order in which the accepted formats are declared when looking for the format to select" do
      mock_app {
        register Sinatra::REST::Routes
        get '/', :provides => ["application/json", "application/xml", "application/vnd.x.y.z+xml"] do
          request.env['HTTP_ACCEPT']
        end
      }
      get '/', {}, { 'HTTP_ACCEPT' => 'application/xml, */*' }
      assert_equal 200, last_response.status
      assert_equal 'application/xml, */*', last_response.body
      assert_equal 'application/xml', last_response.headers['Content-Type']
    end
    test "should be successful if the accepted type does not require a specific level" do
      mock_app {
        register Sinatra::REST::Routes
        get '/', :provides => ["application/xml;level=5"] do
          request.env['HTTP_ACCEPT']
        end
      }
      get '/', {}, { 'HTTP_ACCEPT' => 'application/xml' }
      assert last_response.ok?
      assert_equal 'application/xml', last_response.body
      assert_equal 'application/xml;level=5', last_response.headers['Content-Type']
    end
    test "should be successful if the accepted type level is greater than what is supported" do
      mock_app {
        register Sinatra::REST::Routes
        get '/', :provides => ["application/xml;level=5"] do
          request.env['HTTP_ACCEPT']
        end
      }
      get '/', {}, { 'HTTP_ACCEPT' => 'application/xml;level=6' }
      assert last_response.ok?
      assert_equal 'application/xml;level=6', last_response.body
      assert_equal 'application/xml;level=5', last_response.headers['Content-Type']
    end
  end
  
  context "route option :decode" do
    setup do
      PARSING_PROC = Proc.new{|content_type, content| content_type =~ /^application\/.*json$/i ? JSON.parse(content) : throw(:halt, [400, "Cannot parse"])} unless defined? PARSING_PROC
    end
    test "should return 400 if the input content is empty" do
      mock_app {
        register Sinatra::REST::Routes
        post '/', :decode => PARSING_PROC do
          request.env['sinatra.decoded_input'].inspect
        end
      }
      post '/', "", {'CONTENT_TYPE' => "application/json"}
      assert_equal 400, last_response.status
      assert_equal 'Input data size must be between 1 and 1073741824 bytes.', last_response.body
      assert_equal 'text/plain', last_response.headers['Content-Type']
    end
    test "should return 400 if the input content is too large" do
      mock_app {
        register Sinatra::REST::Routes
        post '/', :decode => [PARSING_PROC, 2...30] do
          request.env['sinatra.decoded_input'].inspect
        end
      }
      post '/', '{"key1": ["value1", "value2"]}', {'CONTENT_TYPE' => "application/json"}
      assert_equal 400, last_response.status
      assert_equal 'Input data size must be between 2 and 30 bytes.', last_response.body
      assert_equal 'text/plain', last_response.headers['Content-Type']
    end
    test "should return 400 if the input content can be parsed but is malformed" do
      mock_app {
        register Sinatra::REST::Routes
        post '/', :decode => [PARSING_PROC, 2..30] do
          request.env['sinatra.decoded_input'].inspect
        end
      }
      post '/', '{"key1": ["value1", "value2"]', {'CONTENT_TYPE' => "application/json"}
      assert_equal 400, last_response.status
      assert_equal "JSON::ParserError: 618: unexpected token at '{\"key1\": [\"value1\", \"value2\"]'", last_response.body
      assert_equal 'text/plain', last_response.headers['Content-Type']
    end
    test "should allow the parsing proc to throw an exception if needed (e.g. no parser can be found for the requested content type)" do
      mock_app {
        register Sinatra::REST::Routes
        post '/', :decode => [PARSING_PROC, 2..30] do
          request.env['sinatra.decoded_input'].inspect
        end
      }
      post '/', '<item></item>', {'CONTENT_TYPE' => "application/xml"}
      assert_equal 400, last_response.status
      assert_equal "Cannot parse", last_response.body
      assert_equal 'text/html', last_response.headers['Content-Type']
    end
    test "should correctly parse the input content if a parser can be found for the specified content type, and the decoded input must be made available in env['sinatra.decoded_input']" do
      input = {"key1" => ["value1", "value2"]}
      mock_app {
        register Sinatra::REST::Routes
        post '/', :decode => [PARSING_PROC, 2...30] do
          content_type 'application/json'
          JSON.dump request.env['sinatra.decoded_input']
        end
      }
      post '/', JSON.dump(input), {'CONTENT_TYPE' => "application/json"}
      assert_equal 200, last_response.status
      assert_equal JSON.dump(input), last_response.body
      assert_equal 'application/json', last_response.headers['Content-Type']
    end
    test "should work" do
      input = "{\"walltime\":3600,\"resources\":\"/nodes=1\",\"at\":1258552306,\"on_launch\":{\"in\":\"/home/crohr\",\"do\":\"id\"}}" 
      mock_app {
        register Sinatra::REST::Routes
        post '/', :decode => [PARSING_PROC, 2...3000] do
          content_type 'application/json'
          JSON.dump request.env['sinatra.decoded_input']
        end
      }
      post '/', input, {'CONTENT_TYPE' => "application/json"}
      p last_response.body
      assert_equal 200, last_response.status
      assert_equal JSON.parse(input), JSON.parse(last_response.body)
      assert_equal 'application/json', last_response.headers['Content-Type']
    end
    test "should set the decoded input to the params hash already decoded by Sinatra, if the request's content type is application/x-www-form-urlencoded" do
      input = {"key1" => ["value1", "value2"]}
      mock_app {
        register Sinatra::REST::Routes
        post '/', :decode => [PARSING_PROC, 2...30] do
          content_type 'application/json'
          JSON.dump request.env['sinatra.decoded_input']
        end
      }
      post '/', input
      assert_equal 200, last_response.status
      assert_equal JSON.dump(input), last_response.body
      assert_equal 'application/json', last_response.headers['Content-Type']
    end
    test "should return 400 if the parsing proc raises a StandardError" do
      mock_app {
        register Sinatra::REST::Routes
        post '/', :decode => Proc.new{|content_type, content| raise(StandardError, "error message") } do
          request.env['sinatra.decoded_input'].inspect
        end
      }
      post '/', 'whatever content', {'CONTENT_TYPE' => "whatever type"}
      assert_equal 400, last_response.status
      assert_equal "StandardError: error message", last_response.body
      assert_equal 'text/plain', last_response.headers['Content-Type']
    end
    test "should raise an error if the first argument is not a proc" do
     assert_raise(ArgumentError){ mock_app {
        register Sinatra::REST::Routes
        disable :raise_errors, :show_exceptions
        post '/', :decode => :whatever do
          JSON.dump request.env['sinatra.decoded_input']
        end
      } }
    end
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
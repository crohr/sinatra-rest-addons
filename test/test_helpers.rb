require File.dirname(__FILE__) + '/helper'
require 'json'

class HelpersTest < Test::Unit::TestCase
  
  context "helper :provides" do
  
    test "should return 406 and the list of supported types, if the server does not support the types accepted by the client [simple matching]" do
      mock_app {
        helpers Sinatra::REST::Helpers
        get '/' do
          provides "application/xml", "application/vnd.x.y.z+xml"
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
        helpers Sinatra::REST::Helpers
        get '/' do
          provides "application/xml;level=5"
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
        helpers Sinatra::REST::Helpers
        get '/' do
          provides "application/xml", "application/vnd.x.y.z+xml"
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
        helpers Sinatra::REST::Helpers
        get '/' do
          provides "application/json", "application/xml", "application/vnd.x.y.z+xml"
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
        helpers Sinatra::REST::Helpers
        get '/' do
          provides "application/xml;level=5"
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
        helpers Sinatra::REST::Helpers
        get '/' do
          provides "application/xml;level=5"
          request.env['HTTP_ACCEPT']
        end
      }
      get '/', {}, { 'HTTP_ACCEPT' => 'application/xml;level=6' }
      assert last_response.ok?
      assert_equal 'application/xml;level=6', last_response.body
      assert_equal 'application/xml;level=5', last_response.headers['Content-Type']
    end
  end
  
  context "helper :decode" do
    setup do
      PARSING_PROC = Proc.new{|content_type| content_type =~ /^application\/.*json$/i ? JSON : nil} unless defined?(PARSING_PROC)
    end
    test "should return 400 if the input content is empty" do
      mock_app {
        helpers Sinatra::REST::Helpers
        post '/' do
          data = decode PARSING_PROC
        end
        error 400 do
          content_type :txt
          "#{response.body.to_s}"
        end
      }
      post '/', "", {'CONTENT_TYPE' => "application/json"}
      assert_equal 400, last_response.status
      assert_equal 'Input data size must be between 1 and 1073741824 bytes.', last_response.body
      assert_equal 'text/plain', last_response.headers['Content-Type']
    end
    test "should return 400 if the input content is too large" do
      mock_app {
        helpers Sinatra::REST::Helpers
        post '/' do
          decode PARSING_PROC, :size_range => 2...30
        end
      }
      post '/', '{"key1": ["value1", "value2"]}', {'CONTENT_TYPE' => "application/json"}
      assert_equal 400, last_response.status
      assert_equal 'Input data size must be between 2 and 30 bytes.', last_response.body
    end
    test "should return 400 if the input content can be parsed but is malformed" do
      mock_app {
        helpers Sinatra::REST::Helpers
        post '/'do
          decode PARSING_PROC, :size_range => 2...30
        end
      }
      post '/', '{"key1": ["value1", "value2"]', {'CONTENT_TYPE' => "application/json"}
      assert_equal 400, last_response.status
      assert_equal "JSON::ParserError: 618: unexpected token at '{\"key1\": [\"value1\", \"value2\"]'", last_response.body
    end
    test "should return 415 if the parsing proc does not return a parser" do
      mock_app {
        helpers Sinatra::REST::Helpers
        post '/' do
          decode PARSING_PROC
        end
      }
      post '/', '<item></item>', {'CONTENT_TYPE' => "application/xml"}
      assert_equal 415, last_response.status
      assert_equal "Format application/xml not supported", last_response.body
    end
    test "should correctly parse the input content if a parser can be found for the specified content type, and the decoded input must be returned" do
      input = {"key1" => ["value1", "value2"]}
      mock_app {
        helpers Sinatra::REST::Helpers
        post '/' do
          data = decode PARSING_PROC, :size_range => 2...30
          content_type 'application/json'
          JSON.dump data
        end
      }
      post '/', JSON.dump(input), {'CONTENT_TYPE' => "application/json"}
      assert_equal 200, last_response.status
      assert_equal JSON.dump(input), last_response.body
      assert_equal 'application/json', last_response.headers['Content-Type']
    end
    test "should set the decoded input to the params hash already decoded by Sinatra, if the request's content type is application/x-www-form-urlencoded" do
      input = {"key1" => ["value1", "value2"]}
      mock_app {
        helpers Sinatra::REST::Helpers
        post '/' do
          data = decode PARSING_PROC, :size_range => 2...30
          content_type 'application/json'
          JSON.dump data
        end
      }
      post '/', input
      assert_equal 200, last_response.status
      assert_equal JSON.dump(input), last_response.body
      assert_equal 'application/json', last_response.headers['Content-Type']
    end
    test "should raise an error if the first argument is not a proc" do
     mock_app {
        helpers Sinatra::REST::Helpers
        post '/' do
          decode :whatever
        end
      }
      assert_raise(ArgumentError){ post '/' }
    end
  end
  
end
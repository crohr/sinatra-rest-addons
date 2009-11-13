require 'rack'
require 'digest/sha1'

module Sinatra
  module REST
    # 
    # Include it with:
    #   class App < Sinatra::Base
    #     helpers Sinatra::RestHelpers
    #   end
    # 
    module Helpers
      INFINITY = 1/0.0
      # e.g.:
      #   get '/x/y/z' do
      #     provides "application/json", :xml, :zip, "text/html;level=5"
      #   end
      # e.g.
      #   get '/', :provides => [:xml, "text/html;level=5"] { "hello" }
      # will accept requests with Accept header =
      # * application/xml
      # * application/*
      # * text/html
      # * text/html;level=5
      # * text/html;level=6
      def provides *formats
        generate_type_hash = Proc.new{ |header| 
          type, *params = header.split(/;\s*/)
          Hash[*params.map{|p| p.split(/\s*=\s*/)}.flatten].merge("type" => type)
        }
        condition {
          supported_formats = formats.map do |f| 
            # selects the correct mime type if a symbol is given
            f.is_a?(Symbol) ? ::Rack::Mime::MIME_TYPES[".#{f.to_s}"] : f
          end.compact.map do |f|
            generate_type_hash.call(f)
          end
          # request.accept is an Array
          accepted_formats = request.accept.map do |f| 
            generate_type_hash.call(f)
          end
          selected_format = supported_formats.detect{ |supported_format| 
            !accepted_formats.detect{ |accepted_format| 
              Regexp.new(Regexp.escape(accepted_format["type"]).gsub("\\*", ".*?"), Regexp::IGNORECASE) =~ supported_format["type"] &&
                (accepted_format["level"] || INFINITY).to_f >= (supported_format["level"] || 0).to_f
            }.nil?
          }      
          if selected_format.nil?
            content_type :txt
            halt 406, supported_formats.map{|f| 
              output = f["type"]
              output.concat(";level=#{f["level"]}") if f.has_key?("level")
              output
            }.join(",")
          else
            response.headers['Content-Type'] = "#{selected_format["type"]}#{selected_format["level"].nil? ? "" : ";level=#{selected_format["level"]}"}"
          end
        }
      end
    
      # Allow access to the route based on the result of the given proc, whose arguments are the request's user and password.
      # You MUST declare two helpers functions named <tt>user</tt> and <tt>password</tt> that respectively return the username and the password of the client.
      def allow(proc)
        condition {
          unless proc.call(user, password)
            halt 403, "You cannot access this resource"
          end
        }
      end
    
    
      # Automatically decode the input data (coming from a POST or PUT request) based on the request's content-type.
      # First argument must be a parsing procedure that will be used to parse the input data according to its content type.
      # The decoded input will be available in request.env['sinatra.decoded_input']
      # e.g.
      #   post  '/', 
      #         :decode => Proc.new{ |content_type, content| 
      #           content_type =~ /^application\/.*json$/i ? JSON.parse(content) : throw(:halt, [400, "Don't know how to parse '#{content_type}' content."])
      #         } do 
      #     "#{request.env['sinatra.decoded_input']}"
      #   end
      def decode(*args)
        parsing_proc = args.shift
        max_size = args.shift || (0..(1024**3))
        condition {
          begin
            case (mime_type = request.env['CONTENT_TYPE'])
            when nil, ""
              halt 400, "You must provide a Content-Type HTTP header."
            when /application\/x-www-form-urlencoded/i
              request.env['sinatra.decoded_input'] = request.env['rack.request.form_hash']
            else
              if parsing_proc
                content = ""
                request.env['rack.input'].each_line do |block|
                  content.concat block
                  halt 400, "Input data size must be between #{max_size.begin} and #{max_size.end} bytes." if not max_size.include?(content.length)
                end
                halt 400, "Input data size must not be empty." if content.empty?
                request.env['sinatra.decoded_input'] = parsing_proc.call(mime_type, content)
              else
                halt 400, "Cannot parse the input data."
              end
            end
          rescue StandardError => e
            halt 400, "#{e.class.name}: #{e.message}"
          end
        }
      end
    
    
      # parser_selector must respond to :select(content_type) and return a parser object with a :load method.
      def parse_input_data!(parser_selector, options = {:limit => 10*1024})
        case (mime_type = request.env['CONTENT_TYPE'])
        when nil
          halt 400, "You must provide a Content-Type HTTP header."
        when /application\/x-www-form-urlencoded/i
          request.env['rack.request.form_hash']
        else
          input_data = request.env['rack.input'].read
          halt 400, "Input data size must not be empty and must not exceed #{options[:limit]} bytes." if (options[:limit] && input_data.length > options[:limit]) || input_data.length == 0
          parser_selector.select(mime_type).load(input_data)
        end
      rescue StandardError => e
        halt 400, "#{e.class.name}: #{e.message}"
      end
      def compute_etag(*args)  # :nodoc:
        raise ArgumentError, "You must provide at least one parameter for the ETag computation" if args.empty?
        Digest::SHA1.hexdigest(args.join("."))
      end
    
    end
  end
end

require 'sinatra/base'

module Sinatra
  module REST
    # Include it with:
    #   class App < Sinatra::Base
    #     register Sinatra::REST::Routes
    #   end
    module Routes
      INFINITY = 1/0.0
      
      # Allow the definition of OPTIONS routes
      def options(path, opts={}, &bk);   route 'OPTIONS',   path, opts, &bk end
      
      # e.g.
      #   get '/', :provides => [:xml, "text/html;level=5"] { "hello" }
      # will accept requests with Accept header =
      # * application/xml
      # * application/*
      # * text/html
      # * text/html;level=5
      # * text/html;level=6
      def provides(*formats)
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
          selected_format = nil
          accepted_formats.each{ |accepted_format| 
            selected_format = supported_formats.detect{ |supported_format| 
              Regexp.new(Regexp.escape(accepted_format["type"]).gsub("\\*", ".*?"), Regexp::IGNORECASE) =~ supported_format["type"] &&
                (accepted_format["level"] || INFINITY).to_f >= (supported_format["level"] || 0).to_f
            }
            break unless selected_format.nil?
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
      end # def provides
    
      # Allow access to the route based on the result of the given proc, whose argument is a <tt>credentials</tt> object.
      # You MUST declare a helper function named <tt>credentials</tt> that will return an object (of your choice) containing the client's credentials, 
      # that will be passed as an argument to the given Proc.
      # Halts the response process with a 403 status code if the given proc returns false (you may then process the error with a <tt>error 403 {}</tt> block).
      # e.g.
      #   helpers do
      #     def credentials; [params["user"], params["password"]]; end
      #   end
      #   get  '/', :allow => Proc.new{ |credentials| credentials.first == "someone" && credentials.last == "password" } do 
      #     "allowed"
      #   end
      def allow(proc)
        raise ArgumentError, "You must provide a Proc that returns true or false when given the result of a call to the 'credentials' helper" unless proc.kind_of?(Proc)
        condition {
          unless proc.call(credentials)
            halt 403, "You cannot access this resource"
          end
        }
      end # def allow
    
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
        args = [args] unless args.kind_of? Array
        parsing_proc  = args.shift
        raise ArgumentError, "You must provide a proc to parse the input data" unless parsing_proc.kind_of?(Proc)
        size_range    = args.shift || (1..(1024**3))
        condition {
          begin
            case (mime_type = request.env['CONTENT_TYPE'])
            when /^application\/x-www-form-urlencoded/i
              request.env['sinatra.decoded_input'] = request.env['rack.request.form_hash']
            else
              if not size_range.include?(request.env['rack.input'].size)
                content_type :txt
                halt 400, "Input data size must be between #{size_range.begin} and #{size_range.end} bytes."
              else
                content = request.env['rack.input'].read
                request.env['sinatra.decoded_input'] = parsing_proc.call(mime_type, content)
              end
            end
          rescue StandardError => e  
            content_type :txt
            halt 400, "#{e.class.name}: #{e.message}"
          end
        }
      end # def decode
      
    end # module Routes
  end # module REST
end # module Sinatra

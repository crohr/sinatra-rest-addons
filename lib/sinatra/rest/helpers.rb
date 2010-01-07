require 'digest/sha1'

module Sinatra
  module REST
    # Include it with:
    #   class App < Sinatra::Base
    #     helpers Sinatra::REST::Helpers
    #   end
    module Helpers  
      
      INFINITY = 1/0.0
        
      def compute_etag(*args)
        raise ArgumentError, "You must provide at least one parameter for the ETag computation" if args.empty?
        Digest::SHA1.hexdigest(args.join("."))
      end
      
      # e.g.
      #   get '/' do
      #     provides :xml, "text/html;level=5"
      #     "Hello"
      #   end
      # will accept requests having an Accept header containing at least one of the following value:
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
      end # def provides


      # Automatically decode the input data (coming from a POST or PUT request) based on the request's content-type.
      # You must pass a Proc that will return the parser object to use to decode the payload.
      # The parser object must respond to a <tt>parse</tt> method.
      # You may also pass a hash of options:
      # * <tt>:size_range</tt>: byte range specifying the minimum and maximum length (in bytes) of the payload [default=(1..1024**3)]
      # 
      # e.g.
      #   post  '/resource' do
      #     data = decode lambda{|content_type| if content_type =~ /^application\/.*json$/i then JSON}, :size_range => (1..2*1024**3)
      #   end
      # 
      # The processing of the request will be halted in the following cases:
      # * 400 if the payload is not within the specified size range.
      # * 400 if the payload cannot be correctly parsed.
      # * 415 if the payload's content type is not supported (i.e. the given Proc returns nil)
      # 
      def decode(proc, config = {})
        raise ArgumentError, "You must pass an object that responds to #call" unless proc.respond_to?(:call)
        size_range = config.delete(:size_range) || (1..(1024**3))
        case (mime_type = request.env['CONTENT_TYPE'])
        when /^application\/x-www-form-urlencoded/i
          request.env['sinatra.decoded_input'] = request.env['rack.request.form_hash']
        else
          content = ""
          request.env['rack.input'].each do |block|
            content.concat(block)
            break if content.length > size_range.end
          end
          if not size_range.include?(content.length)
            halt 400, "Input data size must be between #{size_range.begin} and #{size_range.end} bytes."
          elsif parser = proc.call(mime_type)
            begin
              parser.parse(content)
            rescue StandardError => e  
              halt 400, "#{e.class.name}: #{e.message}"
            end
          else
            halt 415, "Format #{mime_type} not supported"
          end
        end
      end # def decode
    end # module Helpers
  end # module REST
end # module Sinatra

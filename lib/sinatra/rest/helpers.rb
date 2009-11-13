require 'digest/sha1'

module Sinatra
  module REST
    # Include it with:
    #   class App < Sinatra::Base
    #     helpers Sinatra::REST::Helpers
    #   end
    module Helpers    
      def compute_etag(*args)
        raise ArgumentError, "You must provide at least one parameter for the ETag computation" if args.empty?
        Digest::SHA1.hexdigest(args.join("."))
      end
    end # module Helpers
  end # module REST
end # module Sinatra

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
      
    end # module Routes
  end # module REST
end # module Sinatra

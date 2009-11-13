require 'sinatra/base'
module Sinatra
  
  module REST
    
    module Routes
      def options(path, opts={}, &bk);   route 'OPTIONS',   path, opts, &bk end
    end
    
  end
  
  register REST::Routes
end

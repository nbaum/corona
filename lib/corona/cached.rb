
module Corona
  
  module Cached
    
    module ClassMethods
      
      def cache
        @cache ||= {}
      end
      
      def new (*args)
        cache[args] ||= super(*args)
      end
      
    end
    
    def self.included (other)
      other.extend(ClassMethods)
    end
    
  end
  
end


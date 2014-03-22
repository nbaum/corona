
module Corona
  
  module Cached
    
    module ClassMethods
      
      def self.cache
        @cache ||= {}
      end
      
      def self.new (*args)
        cache[args] ||= super(*args)
      end
      
    end
    
    def self.included (other)
      other.extend(ClassMethods)
    end
    
  end
  
end


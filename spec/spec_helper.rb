$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'background_queue'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  
end

#i want to be able to test private methods
#this will let me prefix the call with __prv__ and it will then use send to route to the private call
#this assumes the class getting tested does not use method_missing
class Object
  
  alias_method :_original_method_missing, :method_missing
  
  def method_missing(sym, *args, &block)
    if sym.to_s[0, 7] == "__prv__"
      #we are explicily saying this should be a private method.. lets make sure...
      
      private_method = sym.to_s[7, sym.to_s.length - 7].intern
      
      raise "Method #{private_method} is public when it was expected to be private" if respond_to?(private_method)
      
      send private_method, *args, &block
    else
      _original_method_missing(sym, *args, &block)
    end
  end
  
  
end

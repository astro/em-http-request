module EventMachine
  class MockHttpRequest < EventMachine::HttpRequest
    
    include HttpEncoding
    
    class FakeHttpClient < EventMachine::HttpClient

      def setup(response, uri)
        @uri = uri
        receive_data(response)
        succeed(self) 
      end
      
      def unbind
      end
      
    end
    
    @@registry = nil
    @@registry_count = nil
    
    def self.reset_counts!
      @@registry_count = Hash.new{|h,k| h[k] = Hash.new(0)}
    end
    
    def self.reset_registry!
      @@registry = Hash.new{|h,k| h[k] = {}}
    end
    
    reset_counts!
    reset_registry!
    
    @@pass_through_requests = true

    def self.pass_through_requests=(pass_through_requests)
      @@pass_through_requests = pass_through_requests
    end
    
    def self.pass_through_requests
      @@pass_through_requests
    end
    
    def self.register(uri, method, data)
      method = method.to_s.upcase
      @@registry[uri][method] = data
    end
    
    def self.register_file(uri, method, file)
      register(uri, method, File.read(file))
    end
    
    def self.count(uri, method)
      method = method.to_s.upcase
      @@registry_count[uri][method]
    end
    
    alias_method :real_send_request, :send_request
    
    protected
    def send_request(&blk)
      query = "#{@uri.scheme}://#{@uri.host}:#{@uri.port}#{encode_query(@uri.path, @options[:query], @uri.query)}"
      if s = @@registry[query] and fake = s[@method]
        @@registry_count[query][@method] += 1
        client = FakeHttpClient.new(nil)
        client.setup(fake, @uri)
        client
      elsif @@pass_through_requests
        real_send_request
      else
        raise "this request #{query} for method #{@method} isn't registered, and pass_through_requests is current set to false"
      end
    end
  end
end

require 'base64'
require 'addressable/uri'

module EventMachine

  # EventMachine based HTTP request class with support for streaming consumption
  # of the response. Response is parsed with a Ragel-generated whitelist parser
  # which supports chunked HTTP encoding.
  #
  # == Example
  #
  #  EventMachine.run {
  #    http = EventMachine::HttpRequest.new('http://127.0.0.1/').get :query => {'keyname' => 'value'}
  #
  #    http.callback {
  #     p http.response_header.status
  #     p http.response_header
  #     p http.response
  #
  #	EventMachine.stop
  #    }
  #  }
  #

  class HttpRequest
    
    attr_reader :options, :method

    def initialize(host, headers = {})
      @headers = headers
      @uri = host.kind_of?(Addressable::URI) ? host : Addressable::URI::parse(host)
    end

    # Send an HTTP request and consume the response. Supported options:
    #
    #   head: {Key: Value}
    #     Specify an HTTP header, e.g. {'Connection': 'close'}
    #
    #   query: {Key: Value}
    #     Specify query string parameters (auto-escaped)
    #
    #   body: String
    #     Specify the request body (you must encode it for now)
    #
    #   on_response: Proc
    #     Called for each response body chunk (you may assume HTTP 200
    #     OK then)
    #
                                   
    def get    options = {}, &blk;  setup_request(:get,  options, &blk);    end
    def head   options = {}, &blk;  setup_request(:head, options, &blk);    end
    def delete options = {}, &blk;  setup_request(:delete, options, &blk);  end
    def put    options = {}, &blk;  setup_request(:put, options, &blk);     end
    def post   options = {}, &blk;  setup_request(:post, options, &blk);    end

    protected

    def setup_request(method, options, &blk)
      raise ArgumentError, "invalid request path" unless /^\// === @uri.path
      @options = options
      
      if proxy = options[:proxy]
        @host_to_connect = proxy[:host]
        @port_to_connect = proxy[:port]
      else
        @host_to_connect = options[:host] || @uri.host
        @port_to_connect = options[:port] || @uri.port
      end                                      
      
      # default connect & inactivity timeouts        
      @options[:timeout] = 10 if not @options[:timeout]  

      # Make sure the ports are set as Addressable::URI doesn't
      # set the port if it isn't there
      if @uri.scheme == "https"
        @uri.port ||= 443
        @port_to_connect ||= 443
      else
        @uri.port ||= 80
        @port_to_connect ||= 80
      end
      
      @method = method.to_s.upcase
      send_request(&blk)
    end
    
    def send_request(&blk)
      begin
      raise ArgumentError, "invalid host" unless @host_to_connect
      raise ArgumentError, "invalid port" unless @port_to_connect
               
       EventMachine.connect(@host_to_connect, @port_to_connect, EventMachine::HttpClient) { |c|
          c.uri = @uri
          c.method = @method
          c.options = @options || {}
          if options.has_key?(:timeout) && options[:timeout]
            c.comm_inactivity_timeout = options[:timeout]
            c.pending_connect_timeout = options[:timeout] if c.respond_to?(:pending_connect_timeout)
          elsif options.has_key?(:timeout)
            c.comm_inactivity_timeout = 5
            c.pending_connect_timeout = 5 if c.respond_to?(:pending_connect_timeout)
          end
          blk.call(c) unless blk.nil?
        }
      rescue EventMachine::ConnectionError => e
        conn = EventMachine::HttpClient.new("")
        conn.on_error(e.message, true)
        conn
      end
    end
  end
end
require 'base64'
require 'addressable/uri'

module EventMachine

  # EventMachine based HTTP request class with support for streaming consumption
  # of the response. Response is parsed with a Ragel-generated whitelist parser
  # which supports chunked HTTP encoding.
  #
  # == Example
  #
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
    #   host: String
    #     Manually specify TCP connect host address, independent of
    #     Host: header

    def get  options = {};    send_request(:get,  options);    end
    def head options = {};    send_request(:head, options);    end
    def post options = {};    send_request(:post, options);    end

    protected

    def send_request(method, options)
      raise ArgumentError, "invalid request path" unless /^\// === @uri.path

      # Make sure the port is set as Addressable::URI doesn't set the
      # port if it isn't there.
      @uri.port = @uri.port ? @uri.port : 80
      method = method.to_s.upcase
      begin
       host = options[:host] || @uri.host
       raise ArgumentError, "invalid host" unless host
       raise ArgumentError, "invalid port" unless @uri.port
       EventMachine.connect(host, @uri.port, EventMachine::HttpClient) { |c|
          c.uri = @uri
          c.method = method
          c.options = options
          if options.has_key?(:timeout) && options[:timeout]
            c.comm_inactivity_timeout = options[:timeout]
            c.pending_connect_timeout = options[:timeout] if c.respond_to?(:pending_connect_timeout)
          elsif options.has_key?(:timeout)
            c.comm_inactivity_timeout = 5
            c.pending_connect_timeout = 5 if c.respond_to?(:pending_connect_timeout)
          end
        }
      rescue RuntimeError => e 
        raise e unless e.message == "no connection"
        conn = EventMachine::HttpClient.new("")
        conn.on_error("no connection", true)
        conn
      end
    end
  end
end

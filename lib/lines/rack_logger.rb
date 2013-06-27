require 'rack/commonlogger'
require 'lines'

module Lines
  class RackLogger < Rack::CommonLogger
    # In development mode the common logger is always inserted
    def self.silence_common_logger!
      Rack::CommonLogger.module_eval("def call(env); @app.call(env); end")
      self
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      began_at = Time.now
      status, header, body = @app.call(env)
      header = Rack::Utils::HeaderHash.new(header)
      body = Rack::BodyProxy.new(body) { log(env, status, header, began_at) }
      [status, header, body]
    end

    protected

    def log(env, status, header, began_at)
      Lines.log(
        remote_addr: env['HTTP_X_FORWARDED_FOR'] || env["REMOTE_ADDR"],
        remote_user: env['REMOTE_USER'] || '',
        method: env['REQUEST_METHOD'],
        path: env['PATH_INFO'],
        query:  env["QUERY_STRING"],
        status: status.to_s[0..3],
        length: extract_content_length(header),
        elapsed: [Time.now - began_at, 's'],
      )
    end
  end
end

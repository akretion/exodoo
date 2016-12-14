require 'rack/reverse_proxy'
require 'nokogiri'
require 'rack'
require 'uri'
require 'exodoo/clipping'


module Rack
  class Lint
    def verify_content_length(bytes)
      # do nothing to avoid errors with proxy clipping in dev mode
    end
  end
end


module RackReverseProxy
  class RoundTrip

    include Exodoo::Clipping

    def rack_response
      body = target_response.body.to_s # NOTE this kills the streaming feature, how much do we care for Odoo?

      if response_headers['Content-Type'] =~ /text\/html/
        body = apply_site_layout(body, env, "//main")
      end
      if target_response.status == 302
        hacked_redirect = URI.parse(response_headers['Location'])
        hacked_redirect.port = source_request.port
        response_headers['Location'] = hacked_redirect.to_s
      end
      [target_response.status, response_headers, [body]]
    end

    # Make sure proxied requests will include Odoo session_id so it will pass the CSRF token check
    def initialize_http_header
      session = env['ooor']['ooor_session']
      session.login_if_required()
      target_request_headers['Cookie'] = "session_id=#{session.web_session[:session_id]}"
      target_request.initialize_http_header(target_request_headers)
    end

    # NOTE: this is EXTREMELY IMPORTANT for security that proxied requests don't pass the session_id to the browser,
    # this is why we filter out the Set-Cookie header from the response
    def format_headers(headers)
      headers.inject({}) do |acc, (key, val)|
        formated_key = key.split("-").map(&:capitalize).join("-")
        acc[formated_key] = Array(val) if formated_key != "Set-Cookie"
        acc
      end
    end
  end
end


require 'rack/reverse_proxy'
require 'nokogiri'
require 'rack'


module Rack
  class Lint
    def verify_content_length(bytes)
      # do nothing to avoid errors with proxy clipping in dev mode
    end
  end
end


module RackReverseProxy
  class RoundTrip

    def rack_response
      body = target_response.body
      place_holder = Net::HTTP.get_response(URI("http://localhost:3333/proxy")) # TODO dynamic
      doc = Nokogiri::XML(body.to_s)
      main = doc.xpath("//main")[0].to_s
      body2 = place_holder.body.gsub('mainnn', main)
      [target_response.status, response_headers, [body2]]
    end

    # Make sure proxied requests will include Odoo session_id so it will pass the CSRF token check
    def initialize_http_header
      target_request_headers['Cookie'] = "session_id=#{env['ooor']['ooor_session'].web_session[:session_id]}"
      p "PROXYYYYYYYYYYY", env['ooor']['ooor_session'].web_session[:session_id]
      p "PROXYYYYYYY2222", env['ooor']['ooor_session']
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


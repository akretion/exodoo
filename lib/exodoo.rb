require 'ostruct'
require 'ooor/rack'
require 'erpify'
require 'locomotive/steam'
require 'rack/reverse_proxy'


module Locomotive
  module Steam
    class Repositories
      register :adapter do
        build_adapter(configuration.adapter).tap do
          require 'exodoo/shopify'
        end
      end
    end
  end
end


module RackReverseProxy
  class RoundTrip

    # Make sure proxied requests will include Odoo session_id so it will pass the CSRF token check
    def initialize_http_header
      target_request_headers['Cookie'] = "session_id=#{env['ooor']['ooor_session'].web_session[:session_id]}"
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

module Exodoo

  require 'locomotive/steam'
  require 'locomotive/steam/middlewares'
  require 'locomotive/steam/server'


  ::Ooor::Rack.ooor_session_config_mapper do |env|
    env['steam.site'] ||= Locomotive::Site.where(handle: ::Rack::Request.new(env).params['site_handle']).first
    site = env['steam.site']
    site && site.metafields[:ooor].try(:compact) || {} # TODO Devise auth
  end

  ::Ooor::Rack.ooor_public_session_config_mapper do |env|
    env['steam.site'] ||= Locomotive::Site.where(handle: ::Rack::Request.new(env).params['site_handle']).first
    site = env['steam.site']
    site && site.metafields[:ooor].try(:compact) || {}
  end

  class Middleware < Locomotive::Steam::Middlewares::ThreadSafe
    include Ooor::RackBehaviour

    def _call
      set_ooor!(env)
      public_session = env['ooor']['ooor_public_session']
      session = env['ooor']['ooor_session']
      erpify_assigns = {
                          "ooor_public_model" => Erpify::Liquid::Drops::OoorModel.new(public_session),
                          "ooor_model" => Erpify::Liquid::Drops::OoorModel.new(session),
                          "session" => Erpify::Liquid::Drops::Session.new(session)
                        }
      env["steam.liquid_assigns"].merge!(erpify_assigns)
    end
  end

  Locomotive::Steam.configure_extension do |config|
    config.middleware.insert_before Locomotive::Steam::Middlewares::Page, Exodoo::Middleware
    config.middleware.insert_after Exodoo::Middleware, Rack::ReverseProxy do
      (Ooor.default_config[:proxies] || []).each do |k, v|
        reverse_proxy(k, v)
      end
    end
  end


  module ContentEntryAdapter
    def content_type
      #locale = Locomotive::Mounter.locale.to_s
      context = {'lang' => 'en_US'} #to_erp_locale(locale)}
      @content_type ||= OpenStruct.new(slug: self.class.param_key(context))
    end

    def content_entry
      self
    end

    def _slug
      CGI.escape(to_param.gsub(' ', '-'))
    end

    def _permalink
      to_param
    end

    def _label
      _display_name
    end

    # TODO next, previous, seo_title, meta_keywords, meta_description, created_at


    def __with_locale__(locale, &block)
      yield
    end
  end

  Ooor::Base.send :include, Exodoo::ContentEntryAdapter


  begin
    config_file = "#{Dir.pwd}/config/ooor.yml"
    config = YAML.load_file(config_file)['development']
    Ooor.default_config = HashWithIndifferentAccess.new(config).merge(locale_rack_key: 'steam.locale')
  rescue SystemCallError
    puts """failed to load OOOR yaml configuration file.
       make sure your app has a #{config_file} file correctly set up\n\n"""
  end
end


module Locomotive::Steam

  class PageRepository
    def template_for(entry, handle = nil)
      conditions = { templatized: true, target_klass_name: entry.try(:_class_name) }

      conditions[:handle] = handle if handle
      unless conditions[:target_klass_name] # AKRETION; may be implementing _class_name on entries is better
        conditions[:target_klass_name] = "Locomotive::ContentEntryooor_entries"
      end
      all(conditions).first.tap do |page|
        page.content_entry = entry if page
      end
    end
  end


  module Liquid
    module Tags
      module Concerns
        module Path
          def retrieve_page_drop_from_handle
            handle = @context[@handle] || @handle
            case handle
            when String
              _retrieve_page_drop_from(handle)
            when Locomotive::Steam::Liquid::Drops::ContentEntry
              _retrieve_templatized_page_drop_from(handle)
            when Ooor::Base
              _retrieve_templatized_page_drop_from(handle)
            when Locomotive::Steam::Liquid::Drops::Page
              handle
            else
              nil
            end
          end

          def _retrieve_templatized_page_drop_from(drop)
            if drop.is_a?(Ooor::Base)
              entry = drop
            else
              entry = drop.send(:_source)
            end
            if page = repository.template_for(entry, @path_options[:with])
              page.to_liquid.tap { |d| d.context = @context }
            end
          end
        end
      end
    end
  end


  module Middlewares

    class TemplatizedPage

      # monkey patches the method to retrieve a potential Ooor content for the given URL path
      def fetch_content_entry(slug)
        if page.content_type_id == "ooor_entries"
          method_or_key = path.split('/')[0].gsub('-', '.')
          lang = env['ooor']['context']['lang'] || 'en_US'
          session = env['ooor']['ooor_session']
      	  model = session.const_get(method_or_key, lang)
          param = CGI::unescape(slug)
          model.find_by_permalink(param)        elsif type = content_type_repository.find(page.content_type_id)
          decorate(content_entry_repository.with(type).by_slug(slug))
        else
          nil
        end
      end

    end
  end
end

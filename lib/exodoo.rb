require 'ostruct'
require 'json'
require 'ooor/rack'
require 'erpify'
require 'locomotive/steam'
require 'rack/reverse_proxy'
require 'exodoo/shopify/cart'
require 'exodoo/proxy.rb'


module Locomotive
  module Steam
    class Repositories
      register :adapter do
        build_adapter(configuration.adapter).tap do
          require 'exodoo/shopify/i18n_helper'
        end
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
    session = site && site.metafields[:ooor].try(:compact) || {}
    email = env['warden'].try(:user).try(:email)
    session[:email] = email if email
    session.reject {|k,v| v.nil? || v.blank?}
  end

  ::Ooor::Rack.ooor_public_session_config_mapper do |env|
    if defined?(::Locomotive::Wagon)
      # in Wagon use the ooor.yml config directly for simplicity
      ::Ooor.default_config
    else
      env['steam.site'] ||= Locomotive::Site.where(handle: ::Rack::Request.new(env).params['site_handle']).first
      site = env['steam.site']
      if site
        session = site.metafields[:ooor].try(:compact) || {}
        session.reject {|k,v| v.nil? || v.blank?}
      else
        {}
      end
    end
  end


  class Middleware < Locomotive::Steam::Middlewares::ThreadSafe
    include Ooor::RackBehaviour
    include Locomotive::Steam::Middlewares::Helpers

      attr_accessor :app, :env

      def initialize(app)
        @app = app
      end

      def call(env)
        threadsafed = dup
        threadsafed.env = env
        threadsafed._call
      end

      def _call
        if env['PATH_INFO'] =~ /\/products\// && env['warden'] && !env['warden'].authenticated? #env['warden'].user # TODO path not hardcoded
          return redirect_to "/users/sign_in"
        end
        set_ooor!(env)
        public_session = env['ooor']['ooor_public_session']
        session = env['ooor']['ooor_session']
        req = Rack::Request.new(env)
        erpify_assigns = {
                          "ooor_public_model" => Erpify::Liquid::Drops::OoorModel.new(public_session),
                          "ooor_model" => Erpify::Liquid::Drops::OoorModel.new(session),
                          "ooor_session" => Erpify::Liquid::Drops::Session.new(session),
                          "cart" => req.session['cart'] # TODO REMOVE?
                         }
        env["steam.liquid_assigns"].merge!(erpify_assigns)
        @app.call(env)
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
      CGI.escape("#{to_param}-#{id}")
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
      conditions = { templatized: true}#, target_klass_name: entry.try(:_class_name) }

      conditions[:handle] = handle if handle
      # TODO filter Odoo templates, but as for now Odoo templatized pages seems to have no class when coming from Wagon FIXME
#      unless conditions[:target_klass_name] # AKRETION; may be implementing _class_name on entries is better
#        conditions[:target_klass_name] = "Locomotive::ContentEntryooor_entries"
#      end

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
        #if page.content_type_id == "ooor_entries"
        # TODO FIXME in the Engine the page content_type_id is not set when exporting with Wagon!
        if true
          method_or_key = path.split('/')[0].gsub('-', '.')
          lang = env['ooor']['context']['lang'] || 'en_US'
          public_session = env['ooor']['ooor_public_session']
          model = public_session.const_get(method_or_key, lang)
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


module Locomotive::Steam
  module Server

    class << self

      # Strangely the following is required to inject the Exodoo middlewares when using the Rails engine
      # injecting with Locomotive::Steam.configure works with Wagon but not with the Engine...
      def to_app
        stack = configuration.middleware
        stack.insert_before Locomotive::Steam::Middlewares::Page, Exodoo::Middleware
        stack.insert_after Exodoo::Middleware, Exodoo::Cart
        stack.insert_after Exodoo::Middleware, Rack::ReverseProxy do
          (Ooor.default_config[:proxies] || []).each do |k, v|
            reverse_proxy(k, v)
          end
        end

        Rack::Builder.new do
          stack.inject(self)
          run Middlewares::Renderer.new(nil)
        end
      end

    end
  end
end

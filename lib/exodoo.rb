require 'ostruct'
require 'ooor/rack'
require 'erpify'
require 'locomotive/steam'
require 'rack/reverse_proxy'

module Exodoo

  require 'locomotive/steam'
  require 'locomotive/steam/middlewares'
  require 'locomotive/steam/server'


  class Middleware <  Locomotive::Steam::Middlewares::ThreadSafe
    include Ooor::RackBehaviour

    def _call
      set_ooor!(env)
      erpify_assigns = {
                          "ooor_public_model" => Erpify::Liquid::Drops::OoorDefaultModel.new(),
                          "ooor_model" => Erpify::Liquid::Drops::OoorDefaultModel.new(), #no authentication in Wagon
                        }
      env["steam.liquid_assigns"].merge!(erpify_assigns)
    end
  end

  Locomotive::Steam.configure do |config|
    config.middleware.insert_before Locomotive::Steam::Middlewares::Page, Exodoo::Middleware
    config.middleware.insert_before Rack::Rewrite, Rack::ReverseProxy do
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
  module Middlewares
    class TemplatizedPage

      # monkey patches the method to retrieve a potential Ooor content for the given URL path
      def fetch_content_entry(slug)
        if page.content_type_id == "ooor_entries"
          method_or_key = path.split('/')[0].gsub('-', '.')
          lang = env['ooor']['context']['lang'] || 'en_US'
          model = Ooor.session_handler.retrieve_session(Ooor.default_config).const_get(method_or_key, lang)
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

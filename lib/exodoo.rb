require 'ostruct'
require 'ooor/rack'
require 'erpify'
require 'locomotive/steam'


module Exodoo

  require 'locomotive/steam'
  require 'locomotive/steam/middlewares'
  require 'locomotive/steam/server'


  class Middleware <  Locomotive::Steam::Middlewares::ThreadSafe
    def _call
      ooor_rack = Ooor::Rack.new(@app)
      ooor_rack.set_ooor!(env)
      erpify_assigns = {
                          "ooor_public_model" => Erpify::Liquid::Drops::OoorDefaultModel.new(),
                          "ooor_model" => Erpify::Liquid::Drops::OoorDefaultModel.new(), #no authentication in Wagon
                        }
      env["steam.liquid_assigns"].merge!(erpify_assigns)
    end
  end

  Locomotive::Steam.configuration.middleware.insert_before Locomotive::Steam::Middlewares::Page, Exodoo::Middleware


  module ContentEntryAdapter
    def content_type
      locale = Locomotive::Mounter.locale.to_s
      context = {'lang' => to_erp_locale(locale)}
      @content_type ||= OpenStruct.new(slug: self.class.param_key(context))
    end

    def content_entry
      self
    end

    def _slug
      to_param
    end

    def _permalink
      to_param
    end

    def _label
      _display_name
    end

    # TODO next, previous, seo_title, meta_keywords, meta_description, created_at
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

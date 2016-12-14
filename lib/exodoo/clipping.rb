require 'nokogiri'


module Exodoo::Clipping
  def apply_site_layout(html_fragment, env, xpath=nil, request=nil, layout_handle='proxy')
    renderer = ::Locomotive::Steam::Middlewares::Renderer.new(nil)
    renderer.env = env

    if env['steam.services']
      page_finder = renderer.services.page_finder
    else
      env['steam.is_default_host'] = false
      env['steam.request'] = request
      env['steam.locale'] = :en
      env['steam.path'] = layout_handle
      repositories = Locomotive::Steam::Repositories.new(nil, nil, Locomotive::Steam.configuration)
      current_site = Locomotive::Steam::SiteFinderService.new(repositories.site, request).find
      repositories.current_site = current_site
      env['steam.site'] = current_site
      page_finder = Locomotive::Steam::PageFinderService.new(repositories.page)
    end

    env['steam.page'] = page_finder.match(layout_handle).first # TODO look for specialized tpl before
    renderer.env = env
    place_holder = renderer._call()[2][0]

    if xpath
      doc = Nokogiri::HTML(html_fragment)
      html_fragment = doc.xpath(xpath)[0].to_s

      header_fragment = ""
      css_links = doc.xpath("//head//link")
      css_links.each do |css_link|
        header_fragment << css_link.to_s
      end
      js_scripts = doc.xpath("//head//script")
      js_scripts.each do |js_script|
        header_fragment << js_script.to_s
      end

      place_holder.gsub!('<!-- css_place_holder -->', header_fragment)
    end

    body = place_holder.gsub('body_placeholder', html_fragment)

    # TODO the following avoid the double inclusion of jquery but should be more robust!!
    body = body.gsub('<script src="//ajax.googleapis.com/ajax/libs/jquery/1.11.0/jquery.min.js" type="text/javascript" ></script>', '')
  end
end

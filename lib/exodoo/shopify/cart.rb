require 'ostruct'
require 'json'
require 'ooor/rack'
require 'erpify'
require 'locomotive/steam'
require 'rack/reverse_proxy'


class Exodoo::Cart
  attr_accessor_initialize :app
  def call(env)
    if env['PATH_INFO'] == "/cart/add.js"
      session = env['ooor']['ooor_public_session'] || env['ooor']['ooor_session']
      req = Rack::Request.new(env)
      product = session.const_get('product.product').find(req.params['id'])
      qty = req.params['quantity'].to_f
      p product.attributes.keys
      p product.associations.keys
      p product
      p product.associations
      handle = CGI.escape(product.to_param.gsub(' ', '-')),
      data = {id: product.id, # TODO tpl?
              properties: nil, # TODO
              quantity: req.params['quantity'],
              variant_id: product.id,
              key: "TODO",
              title: product.display_name,
              price: product.lst_price,
              original_price: product.list_price,
              discounted_price: product.lst_price,
              line_price: product.lst_price * qty,
              original_line_price: product.list_price * qty,
              total_discount: 0,
              discounts: [],
              sku: product.code,
              grams: product.weight * qty,
              vendor: "", # TODO product.seller_ids.try(:first).try(:name),
              product_id: product.id,
              gift_card: false,
              image: "/web/image/product.product/#{product.id}/image_medium", # TODO
              url: "/#{product.class.param_key}/#{handle}", # TODO lang in context
              handle: handle,
              product_title: product.name,
              product_description: product.description_sale || product.description,
              variant_title: product.name,
              variant_options: [], # TODO
              requires_shipping: true
      }
      req.session['cart'] ||= {
        token: "TODO",
        note: "TODO",
        attributes: {},
        original_total_price: 42,
        total_price: 42,
        total_discount: 0,
        total_weight: 0,
        items: []
      }
      data.stringify_keys!
      req.session['cart'].stringify_keys!
      req.session['cart']['items'] << data # TODO deal with same product
      req.session['cart']['item_count'] = req.session['cart']['items'].size
      req.session['cart']['total_price'] = req.session['cart']['items'].map{|item| item['price']}.inject(0){|sum, x| sum + x }
#      req.session['cart']['total_discount'] = req.session['cart']['items'].size
#      req.session['cart']['total_weight'] = req.session['cart']['items'].size

      @next_response = [200, { 'Content-Type' => 'application/json' }, [JSON.generate(data)]]
    elsif env['PATH_INFO'] == "/cart.js"
      session = env['ooor']['ooor_public_session'] || env['ooor']['ooor_session']
      req = Rack::Request.new(env)
      product = session.const_get('product.product').find(req.params['id'])

      data = { # TODO remove
        token: "TODO",
        note: "TODO",
        attributes: {},
        original_total_price: 42,
        total_price: 42,
        total_discount: 0,
        total_weight: 0,
        item_count: 12, # TODO
        items: req.session['cart']['items'],
        item_count: req.session['cart']['items'].size
      }

      @next_response = [200, { 'Content-Type' => 'application/json' }, [JSON.generate(req.session['cart'])]]
    elsif env['PATH_INFO'] == "/cart/change.js" # POST {"quantity"=>"0", "line"=>"1"}
    elsif env['PATH_INFO'] == "/cart" # POST
      # TODO put stuff into Odoo cart
      session = env['ooor']['ooor_public_session'] || env['ooor']['ooor_session']
      req = Rack::Request.new(env)
      order_id = session.const_get('website').find(:first).sale_get_order_rpc(true, nil, false, false, {}) # NOTE quid du force_create
      order = session.const_get('sale.order').find(order_id)
      p "ooooo", order_id
      req.session['cart']['items'].each do |item|
        p "item", item
        line = session.const_get('sale.order.line').find(order_id: order_id, product_id: item['product_id']).first
        p "lllline", line
        if line
          order.cart_update_rpc(item['product_id'], line.id, 0, item['quantity'])
        else
          order.cart_update_rpc(item['product_id'], nil, 0, item['quantity'])
        end
      end
      @next_response = [ 302, {'Location' =>"shop/checkout"}, [] ]
    else
      app.call(env)
    end
  end
end

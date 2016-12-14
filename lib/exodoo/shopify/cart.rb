require 'ostruct'
require 'json'
require 'ooor/rack'
require 'erpify'
require 'locomotive/steam'
require 'rack/reverse_proxy'


class Exodoo::Cart
  attr_accessor_initialize :app

  def cart_to_cartjs(env)
    session = env['ooor']['ooor_session']
    order_id = session.const_get('website').find(:first).sale_get_order_rpc(true, nil, false, false, {}) # TODO
    order = session.const_get('sale.order').find(order_id)
    cartjs = {'items' => []}
    order.order_line.each do |line|
      product = line.product_id
      qty = line.product_uom_qty
      cartjs['items'] << item_to_cartjs(product, qty)
    end

    cartjs.merge!({
        token: "TODO",
        note: "",
        attributes: {},
        original_total_price: 42,
        total_discount: 0,
        total_weight: 0,
      })
    cartjs.stringify_keys!
    cartjs['item_count'] = cartjs['items'].size
#    cartjs['total_price'] = cartjs['items'].map{|item| item[:price]}.inject(0){|sum, x| sum + x }
      #      session['cart']['total_discount'] = ...
      #      session['cart']['total_weight'] = ...
    cartjs
  end

  def item_to_cartjs(product, qty)
      handle = CGI.escape(product.to_param.gsub(' ', '-')),
      item = {id: product.id, # TODO tpl?
              properties: nil, # TODO
              quantity: qty,
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
              image: "/web/image/product%2Eproduct/#{product.id}/image_medium", # TODO
              url: "/#{product.class.param_key}/#{handle}", # TODO lang in context
              handle: handle,
              product_title: product.name,
              product_description: product.description_sale || product.description,
              requires_shipping: true
      }
      if product.attribute_value_ids
        item['variant_title'] = (product.attribute_value_ids.map {|i| "#{i.name}"}).join(" - ") # TODO test/fix
        item['variant_options'] = [] # TODO
      end
    item.stringify_keys!
  end

  def call(env)
    public_session = env['ooor']['ooor_public_session']
    session = env['ooor']['ooor_session']
    req = Rack::Request.new(env)
    if env['PATH_INFO'] == "/cart/add.js"
      product_id = req.params['id']
      qty = req.params['quantity'].to_f
      p session.public_controller_method('/shop/cart/update/', {product_id: product_id, add_qty: qty})
      product = session.const_get('product.product').find(product_id)
      @next_response = [200, { 'Content-Type' => 'application/json' }, [JSON.generate(item_to_cartjs(product, qty))]]
    elsif env['PATH_INFO'] == "/cart.js"
      @next_response = [200, { 'Content-Type' => 'application/json' }, [JSON.generate(cart_to_cartjs(env))]]
    elsif env['PATH_INFO'] == "/cart/change.js"
      line = req.params['line'].to_i
      qty = req.params['quantity'].to_f
      order_id = session.const_get('website').find(:first).sale_get_order_rpc(true, nil, false, false, {}) # TODO
      order = session.const_get('sale.order').find(order_id)
      product_id = order.order_line[line - 1].product_id.id
      session.public_controller_method('/shop/cart/update/', {product_id: product_id, set_qty: qty})
      @next_response = [200, { 'Content-Type' => 'application/json' }, [JSON.generate(cart_to_cartjs(env))]]
    elsif env['PATH_INFO'] == "/cart" # POST
      cart = req.session['cart'] || {}
      (cart['items'] || []).each do |item|
        session.public_controller_method('/shop/cart/update/', {product_id: item['product_id'], add_qty: item['quantity']})
      end
#      @next_response = [ 302, {'Location' =>"shop/checkout"}, [] ]
      @next_response = [ 302, {'Location' =>"shop/payment"}, [] ] # Cimade specific, normally previous line
    elsif env['PATH_INFO'] == "/shop"
      # TODO flash de confirmation
      @next_response = [ 302, {'Location' =>"/my/home"}, [] ]
    else
      app.call(env)
    end
  end
end

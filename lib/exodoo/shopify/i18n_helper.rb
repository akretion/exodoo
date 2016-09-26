require 'locomotive/steam/adapters/filesystem'

module Locomotive
  module Steam
    module Adapters
      module Filesystem
        module YAMLLoaders

          # NOTE code to load json files in the locales directory just like Shopify templates
          # the code is in part copied from Timber https://github.com/Shopify/Timber/blob/master/spec/helpers/i18n_helper.rb
          class Translation
             EXCLUDED_KEYWORDS = ["date_formats"]

             # we override the Steam load method to also load the json files
             def load(scope)
               super
               array = load_array
               load_json(array)
             end

          private

            def load_json(array)
              hash = {}
              Dir.foreach(File.join(site_path, 'locales')) do |item|
                next if item == '.' or item == '..'
                locale = item.split(".")[0]
                json_path = File.join(site_path, 'locales', item)
                flatten_keys(JSON.parse(File.open(json_path).read)).each_with_object({}) do |(key, value), hash2|
                  next if include_excluded_keywords?(key)
                  hash[truncate_plural_key(key)] ||= {}
                  hash[truncate_plural_key(key)][locale] = value
                end
              end

              hash.each do |k, v|
                array << { key: k, values: v}
              end
              array
            end


            def flatten_keys(entry, keys = [], acc = {})
              if entry.is_a? Hash
                entry.each { |k, v| flatten_keys(v, keys + [k], acc) }
              else
                acc.merge!(keys => entry)
              end
              acc
            end


            def include_excluded_keywords?(key)
              EXCLUDED_KEYWORDS.any? { |w| key.include?(w) }
            end

            def truncate_plural_key(key)
              key.delete_at(-1) if %w{zero one two other}.include?(key.last)
              key.join('.')
            end

          end

        end
      end
    end
  end
end

require 'multi_json'
require 'remq/coder'

# borrowed from Resque::MultiJsonCoder. Thanks @defunkt!

if MultiJson.respond_to?(:adapter)
  raise "Please install the yajl-ruby or json gem" if MultiJson.adapter.to_s == 'MultiJson::Adapters::OkJson'
elsif MultiJson.respond_to?(:engine)
  raise "Please install the yajl-ruby or json gem" if MultiJson.engine.to_s == 'MultiJson::Engines::OkJson'
end

class Remq
  class MultiJsonCoder < Coder
    class EncodeException < StandardError; end
    class DecodeException < StandardError; end

    def encode(object)
      if MultiJson.respond_to?(:dump) && MultiJson.respond_to?(:load)
        MultiJson.dump object
      else
        MultiJson.encode object
      end
    end

    def decode(object)
      return unless object

      begin
        if MultiJson.respond_to?(:dump) && MultiJson.respond_to?(:load)
          MultiJson.load object
        else
          MultiJson.decode object
        end
      rescue ::MultiJson::DecodeError => e
        raise DecodeException, e.message, e.backtrace
      end
    end
  end
end
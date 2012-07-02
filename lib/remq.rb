require 'redis'
require 'remq/script'
require 'remq/multi_json_coder'

class Remq

  attr :redis, :namespace, :scripts, :coder

  def initialize(options = {})
    @redis = options[:redis] || Redis.new(options)
    @namespace = 'remq'
    @scripts = {}
  end

  def publish(channel, message)
    channel = channel.join('.') if channel.is_a?(Array)
    msg, utc_seconds = coder.encode(message), Time.now.to_i
    id = eval_script(:publish, namespace, channel, msg, utc_seconds)
    id.nil? ? nil : id.to_s
  end

  def consume(channel, options = {})
    cursor, limit = options[:cursor] || 0, options[:limit] || 1000
    msgs_ids = eval_script(:consume, namespace, channel, cursor, limit)
    msgs = {}
    msgs_ids.each_index { |i|
      if i % 2 == 0
        msgs[msgs_ids[i+1]] = coder.decode(msgs_ids[i])
      end
    }
    msgs
  end

  def coder
    @coder ||= MultiJsonCoder.new
  end

  protected

    def eval_script(name, *args)
      script(name).eval(@redis, *args)
    end

    def script(name)
      @scripts[name.to_sym] ||= Script.new(File.read(script_path(name)))
    end

    def script_path(name)
      File.expand_path("../vendor/remq/scripts/#{name}.lua", File.dirname(__FILE__))
    end

end

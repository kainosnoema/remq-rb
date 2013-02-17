require 'monitor'
require 'redis'
require 'remq/script'

class Remq
  Message = Struct.new(:channel, :id, :body)

  def Message.parse(raw)
    header, body = raw.split("\n", 2)
    channel, id = header.split('@', 2)
    new(channel, id.to_i, body)
  end

  LIMIT = 1000

  include MonitorMixin

  attr :redis, :predis

  def initialize(options = {})
    @redis     = Redis.new(options)
    @predis    = Redis.new(options) # seperate connection for pub/sub
    @listeners = Hash.new { |h, k| h[k] = [] }

    super() # Monitor#initialize
  end

  def publish(channel, message)
    synchronize do
      id = call(:publish, channel, message)
      id && id.to_i
    end
  end

  def subscribe(pattern, options = {}, &block)
    synchronize do
      return if @subscription

      on(:message, &block) if block

      @subscription = true

      if cursor = options[:from_id]
        @subscription = _subscribe_from_cursor(pattern, cursor)
      else
        @subscription = _subscribe_to_pubsub(pattern)
      end
    end
  end

  def unsubscribe
    synchronize do
      return unless @subscription
      @subscription.exit if @subscription.is_a?(Thread)
      @subscription = nil
    end
  end

  def consume(pattern, options = {})
    synchronize do
      cursor, limit = options.fetch(:cursor, 0), options.fetch(:limit, LIMIT)
      msgs = call(:consume, pattern, cursor, limit)
      msgs.map { |msg| _handle_raw_message(msg) }
    end
  end

  def on(event, proc=nil, &block)
    listener = proc || block
    unless listener.respond_to?(:call)
      raise ArgumentError.new('Listener must respond to #call')
    end

    synchronize do
      @listeners[event.to_sym] << listener
    end

    self
  end

  def off(event, listener)
    synchronize do
      @listeners[event.to_sym].delete(listener)
    end

    self
  end

  def key(*args)
    (['remq'] + args).join(':')
  end

  def inspect
    "#<Remq client v#{Remq::VERSION} for #{redis.client.id}>"
  end

  protected

  def call(name, *args)
    synchronize do
      script(name).eval(redis, *args)
    end
  end

  def emit(event, *args)
    synchronize do
      @listeners[event.to_sym].each { |listener| listener.call(*args) }
    end
  end

  def script(name)
    synchronize do
      (@scripts ||= {})[name.to_sym] ||= begin
        path = "../vendor/remq/scripts/#{name}.lua"
        Script.new(File.read(File.expand_path(path, File.dirname(__FILE__))))
      end
    end
  end

  private

  def _subscribe_from_cursor(pattern, cursor)
    begin
      msgs = consume(pattern, { cursor: cursor })
      cursor = msgs.last.id unless msgs.empty?
    end while msgs.length == LIMIT

    _subscribe_to_pubsub(pattern)
  end

  def _subscribe_to_pubsub(pattern)
    subscribed_thread = nil

    Thread.new do
      begin
        predis.client.connect
        predis.psubscribe(key('channel', pattern)) do |on|
          on.psubscribe { subscribed_thread = Thread.current }
          on.pmessage { |_, _, msg| _handle_raw_message(msg) }
        end
      rescue => e
        Thread.main.raise e
      end
    end

    Thread.pass while !subscribed_thread

    subscribed_thread
  end

  def _handle_raw_message(raw)
    msg = Message.parse raw
    emit(:message, msg.channel, msg) if @subscription
    msg
  end

end

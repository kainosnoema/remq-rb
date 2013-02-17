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

  attr :redis
  attr :predis

  # Create a `Remq` client with the given `options`, which are passed to redis.
  #
  # @param [Hash] options
  def initialize(options = {})
    @redis     = Redis.new(options)
    @predis    = Redis.new(options) # seperate connection for pub/sub
    @listeners = Hash.new { |h, k| h[k] = [] }

    super() # Monitor#initialize
  end

  # Publish a `message` to the given `channel`. The `message` must be a string,
  # but objects can easily be serialized using JSON, etc. The id of the
  # published message will be returned as an integer.
  #
  # @param [String] channel
  # @param [String] message
  #
  # @return [Integer] id
  def publish(channel, message)
    synchronize do
      id = call(:publish, channel, message)
      id && id.to_i
    end
  end

  # Subscribe to the channels matching given `pattern`. If no initial `from_id`
  # is provided, Remq subscribes using vanilla Redis pub/sub. Any Redis pub/sub
  # pattern will work. If `from_id` is provided, Remq replays messages after the
  # given id until its caught up and able to switch to pub/sub.
  #
  # Remq-rb subscribes to pub/sub on another thread, which is returned so you
  # can handle it and call `Thread#join` when ready to block.
  #
  # @param [String] pattern
  # @param [Hash] options
  #   - `:from_id => Integer`: The message id to replay from (usually the last)
  #
  # @yield a block to add as a listener to the `message` event
  # @yieldparam [Remq::Message] received message
  #
  # @return [Thread] thread where messages will be received
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

  # Unsubscribe. No more `message` events will be emitted after this is called.
  def unsubscribe
    synchronize do
      return unless @subscription
      @subscription.exit if @subscription.is_a?(Thread)
      @subscription = nil
    end
  end

  # Consume persisted messages from channels matching the given `pattern`,
  # starting with the `cursor` if provided, or the first message. `limit`
  # determines how many messages will be return each time `consume` is called.
  #
  # @param [String] pattern
  # @param [Hash] options
  #   - `:cursor => Integer`: id of the first message to return
  #   - `:limit => Integer`: maximum number of messages to return
  #
  # @return [Array<Remq::Message>] array of parsed messages
  def consume(pattern, options = {})
    synchronize do
      cursor, limit = options.fetch(:cursor, 0), options.fetch(:limit, LIMIT)
      msgs = call(:consume, pattern, cursor, limit)
      msgs.map { |msg| _handle_raw_message(msg) }
    end
  end

  # Forcibly close the connections to the Redis server.
  def quit
    synchronize do
      redis.quit
      predis.quit
    end
  end

  # Add a listener to the given event.
  #
  # @param [String|Symbol] event
  # @param [Proc] listener
  #
  # @yield a block to be called when the event is emitted
  #
  # @return [Remq] self
  def on(event, listener=nil, &block)
    listener = proc || block
    unless listener.respond_to?(:call)
      raise ArgumentError.new('Listener must respond to #call')
    end

    synchronize do
      @listeners[event.to_sym] << listener
    end

    self
  end

  # Remove a listener from the given event.
  #
  # @param [String|Symbol] event
  # @param [Proc] listener
  #
  # @return [Remq] self
  def off(event, listener)
    synchronize do
      @listeners[event.to_sym].delete(listener)
    end

    self
  end

  # Build a key from the given `name` and `channel`.
  #
  # @param [String] name
  # @param [String] channel
  #
  # @return [String] key
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
      msgs = consume(pattern, { :cursor => cursor })
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

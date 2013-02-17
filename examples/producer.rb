$LOAD_PATH.unshift 'lib'
$LOAD_PATH.unshift 'examples/shared'

require 'json'
require 'remq'
require 'message'

$remq = Remq.new

def publish message
  channel = "events.#{message.type.downcase}.#{message.event}"
  id = $remq.publish(channel, JSON.dump(message.attributes))
  puts "Published ##{id} to channel '#{channel}'"
end

loop do
  publish Message.new
  sleep 0.15
end

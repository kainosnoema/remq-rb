$LOAD_PATH.unshift 'lib'

require 'json'
require 'remq'

$remq = Remq.new

last_id_key = $remq.key('cursor', 'consumer-1')
last_id = $remq.redis.get(last_id_key) || 0

$remq.on(:message) do |channel, message|
  last_id = message.id

  # by persisting the last_id every 10 messages, a maximum of
  # 10 messages will be replayed in the case of consumer failure
  if last_id % 10 == 0
    $remq.redis.set last_id_key, last_id
  end

  message.body = JSON.parse(message.body)
  puts message.inspect
end

thread = $remq.subscribe('events.*', from_id: last_id)

thread.join
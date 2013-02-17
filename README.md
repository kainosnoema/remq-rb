# Remq-rb

A Ruby client for [Remq](https://github.com/kainosnoema/remq), a
[Redis](http://redis.io)-based protocol for building fast, durable message
queues.

NOTE: In early-stage development, API not stable. If you've used a previous
version, you'll most likely have to clear all previously published messages
in order to upgrade to the latest version.

## Installation

``` sh
gem install remq
```

## Usage

**Producer:**

``` rb
require 'json'
require 'remq'

$remq = Remq.new

message = { event: 'signup', account_id: 694 }

id = $remq.publish('events.accounts', JSON.dump(message))
```

**Consumer:**

``` rb
require 'json'
require 'remq'

$remq = Remq.new

last_id_key = $remq.key('cursor', 'consumer-1')
last_id = $remq.redis.get(last_id_key) || 0

$remq.subscribe('events.*', from_id: last_id) do |channel, message|
  last_id = message.id

  # by persisting the last_id every 10 messages, a maximum of
  # 10 messages will be replayed in the case of consumer failure
  if last_id % 10 == 0
    $remq.redis.set(last_id_key, last_id)
  end

  message.body = JSON.parse(message.body)

  puts "Received message on '#{channel}' with id: #{message.id}"
  puts "Account signed up with id: #{message.body['account_id']}"
end
```

**Flush:**

``` rb
# TODO: not implemented yet
```
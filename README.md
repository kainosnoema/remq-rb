# remq-rb [![Build Status][travis-image]][travis-link]

[travis-image]: https://secure.travis-ci.org/kainosnoema/remq-rb.png?branch=master
[travis-link]: http://travis-ci.org/kainosnoema/remq-rb

A Ruby client for [Remq](https://github.com/kainosnoema/remq), a
[Redis](http://redis.io)-based protocol for building fast, durable message
queues.

**WARNING**: In early-stage development, API not stable. If you've used a
previous version, you'll most likely have to clear all previously published
messages in order to upgrade to the latest version.

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

## License

(The MIT License)

Copyright © 2013 Evan Owen &lt;kainosnoema@gmail.com&gt;

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
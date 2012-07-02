# Remq-rb

A Ruby client library for [Remq](https://github.com/kainosnoema/remq), a [Redis](http://redis.io)-based protocol for building fast, persistent pub/sub message queues.

NOTE: In early-stage development, API not locked.

## Usage

**Producer:**

``` rb
require 'remq'

remq = Remq.new

message = { event: 'signup', account_id: 694 }
id = remq.publish('events.accounts', message)
```

**Pub/sub consumer (messages lost during failure):**

``` rb
require 'remq'

remq = Remq.new

# TODO: not implemented yet
```

**Polling consumer with cursor (resumes post-failure):**

``` rb
require 'remq'

remq = Remq.new

# TODO: not implemented yet
```

**Purging old messages:**

``` rb

require 'remq'

remq = Remq.new

# TODO: not implemented yet
```
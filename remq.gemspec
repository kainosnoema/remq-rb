$LOAD_PATH.unshift 'lib'

require 'remq/version'

Gem::Specification.new do |s|
  s.name              = "remq"
  s.version           = Remq::VERSION
  s.date              = Time.now.strftime('%Y-%m-%d')
  s.summary           = "A Remq client library for Ruby."
  s.homepage          = "http://github.com/kainosnoema/remq"
  s.email             = "kainosnoema@gmail.com"
  s.authors           = [ "Evan Owen" ]

  s.files             = `git ls-files`.split("\n")
  s.files            += Dir.glob('vendor/**/*')
  s.test_files        = `git ls-files -- {test,spec,features}/*`.split("\n")

  s.add_dependency    "redis",      "~> 3.0.1"
  s.add_dependency    "multi_json", "~> 1.0"

  s.add_development_dependency "rake"
  s.add_development_dependency "rspec", "~> 2.6"

  s.description = <<description
    Remq is a Redis-based protocol for building fast, persistent
    pub/sub message queues.

    The Remq protocol is defined by a collection of Lua scripts
    (located at https://github.com/kainosnoema/remq) which effectively
    turn Redis into a capable message queue broker for fast inter-service
    communication. The Remq Ruby client library is built on top of these
    scripts, making it easy to build fast, persisted pub/sub message queues.
description
end
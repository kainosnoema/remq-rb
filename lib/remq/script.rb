require 'digest/sha1'

class Remq
  class Script

    attr :source, :sha

    def initialize(source)
      @source = source
    end

    def eval(redis, *args)
      redis.evalsha(sha, [], [*args])
    rescue => e
      if e.message =~ /NOSCRIPT/
        redis.eval(source, [], [*args])
      else
        raise
      end
    end

    def sha
      @sha ||= Digest::SHA1.hexdigest source
    end

  end
end

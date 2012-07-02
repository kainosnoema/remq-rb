require 'remq'

describe Remq do

  before :all do
    subject { Remq.new(db: 4).tap { |r| r.redis.flushdb } }
  end

  after :each do
    subject.redis.flushdb
  end

  context "class" do
    describe ".new" do
      it "creates a Redis client when options hash missing" do
        Remq.new.redis.should be_a(Redis)
      end

      it "takes a Redis client as an option" do
        Remq.new(redis: (redis = Redis.new)).redis.should eql redis
      end
    end
  end

  describe ".publish" do
    it "publishes a message to the given channel and returns an id" do
      id = subject.publish('events.things', { test: 'one' })
      id.should be_a String
    end
  end

  describe ".consume" do
    it "consumes messages published to the given channel" do
      subject.publish('events.things', { 'test' => 'one' })
      subject.publish('events.things', { 'test' => 'two' })
      subject.publish('events.things', { 'test' => 'three' })

      msgs = subject.consume('events.things')
      msgs.should have(3).items
      msgs[msgs.keys[0]].should eql({ 'test' => 'one' })
      msgs[msgs.keys[2]].should eql({ 'test' => 'three' })
    end

    it "limits the messages returned to value given in the :limit option" do
      subject.publish('events.things', { 'test' => 'one' })
      subject.publish('events.things', { 'test' => 'two' })
      subject.publish('events.things', { 'test' => 'three' })

      msgs = subject.consume('events.things', limit: 2)
      msgs.should have(2).items
      msgs[msgs.keys[0]].should eql({ 'test' => 'one' })
      msgs[msgs.keys[1]].should eql({ 'test' => 'two' })
      msgs[msgs.keys[2]].should be_nil
    end

    it "returns messages published since the id given in the :cursor option" do
      cursor = subject.publish('events.things', { 'test' => 'one' })
      subject.publish('events.things', { 'test' => 'two' })
      subject.publish('events.things', { 'test' => 'three' })

      msgs = subject.consume('events.things', cursor: cursor)
      msgs.should have(2).items
      msgs[msgs.keys[0]].should eql({ 'test' => 'two' })
      msgs[msgs.keys[1]].should eql({ 'test' => 'three' })
    end
  end
end
require 'remq'

RSpec::Matchers.define :be_ordered_from do |cursor|
  cursor += 1
  match do |actual|
    actual.each_with_index.map { |msg, i| msg.id == cursor + i }.all?
  end
end

describe Remq do
  subject { Remq.new(db: 4) }

  let(:channel) { 'events.things' }

  before { subject.redis.flushdb }

  def publish n, remq = subject
    (1..n).map { |i| remq.publish(channel, "foo #{i}") }
  end

  def expect_n n, msgs, at = 0
    msgs.should have(n).items
    msgs.each_with_index { |msg, i| msg.body.should eql("foo #{at + i + 1}") }
  end

  describe '#publish' do
    it 'publishes a message to the given channel and returns an id' do
      id = subject.publish(channel, 'foo 1')
      id.should be_a Integer
    end
  end

  describe '#subscribe' do
    let(:producer) { Remq.new(db: 4) }

    it 'receives messages on a separate thread' do
      msgs = []
      thread = subject.subscribe(channel) do |channel, msg|
        msgs << msg
        subject.unsubscribe if msgs.length == 3
      end

      publish 3, producer

      thread.join(1)

      msgs.should have(3).items
      msgs.should be_ordered_from 0
    end

    context 'with :from_id option' do
      it 'catches up to pub/sub from cursor using consume' do
        publish 3, producer

        msgs = []
        thread = subject.subscribe(channel, from_id: 0) do |channel, msg|
          msgs << msg
          subject.unsubscribe if msgs.length == 6
        end

        publish 3, producer

        thread.join(1)

        msgs.should have(6).items
        msgs.should be_ordered_from 0
      end
    end
  end

  describe '#consume' do
    it 'consumes messages published to the given channel' do
      publish 3
      msgs = subject.consume(channel)
      msgs.should have(3).items
      msgs.should be_ordered_from 0
    end

    it 'limits the messages returned to value given in the :limit option' do
      publish 3
      msgs = subject.consume(channel, limit: 2)
      msgs.should have(2).items
      msgs.should be_ordered_from 0
    end

    it 'returns messages published since the id given in the :cursor option' do
      cursor = publish(3).first
      msgs = subject.consume(channel, cursor: cursor)
      msgs.should have(2).items
      msgs.should be_ordered_from cursor
    end
  end
end
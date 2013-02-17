class Message
  EVENTS = %w(create update delete)
  TYPES = %w(Account Subscription Transaction)

  def self.id
    @id ||= 0
    @id += 1
  end

  attr :event, :type, :attributes

  def initialize
    @event = EVENTS.sample
    @type  = TYPES.sample
    @attributes = {
      account_id: self.class.id,
      first_name: 'Evan',
      last_name: 'Owen',
      state: 'active'
    }
  end
end

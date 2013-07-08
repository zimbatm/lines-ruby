require 'active_record'
require 'lines'

module Lines
  class ActiveRecordSubscriber < ActiveSupport::LogSubscriber
    def sql(event)
      payload = event.payload

      return if payload[:name] == 'SCHEMA'

      args = {}

      args[:name] = payload[:name] if payload[:name]
      args[:sql] = payload[:sql].squeeze(' ')

      if payload[:binds] && payload[:binds].any?
        args[:binds] = payload[:binds].inject({}) do |hash,(col, v)|
          hash[col.name] = v
          hash
        end
      end

      args[:elapsed] = [event.duration, 's']

      Lines.log(args)
    end

    def identity(event)
      Lines.log(name: event.payload[:name], line: event.payload[:line])
    end

    def logger; Lines.logger; end
  end
end

ActiveRecord::Base.logger = Lines.logger
Lines::ActiveRecordSubscriber.attach_to :active_record

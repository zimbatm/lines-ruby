require 'active_record'
require 'lines'

module Lines
  class ActiveRecordSubscriber < ActiveSupport::LogSubscriber
    def render_bind(column, value)
      if column
        if column.binary?
          value = "<#{value.bytesize} bytes of binary data>"
        end

        [column.name, value]
      else
        [nil, value]
      end
    end

    def sql(event)
      payload = event.payload

      return if payload[:name] == 'SCHEMA' || payload[:name] == 'EXPLAIN'

      args = {}

      args[:name] = payload[:name] if payload[:name]
      args[:sql] = payload[:sql].squeeze(' ')

      if payload[:binds] && payload[:binds].any?
        args[:binds] = payload[:binds].inject({}) do |hash,(col, v)|
          k, v = render_bind(col, v)
          hash[k] = v
          hash
        end
      end

      args[:elapsed] = [event.duration.round(1), 'ms']

      Lines.log(args)
    end

    def identity(event)
      Lines.log(name: event.payload[:name], line: event.payload[:line])
    end

    def logger; Lines.logger; end
  end
end

# Subscribe lines to the AR events
Lines::ActiveRecordSubscriber.attach_to :active_record

# Remove the default ActiveRecord::LogSubscriber to avoid double outputs
ActiveSupport::LogSubscriber.log_subscribers.each do |subscriber|
  if subscriber.is_a?(ActiveRecord::LogSubscriber)
    component = :active_record
    events = subscriber.public_methods(false).reject{ |method| method.to_s == 'call' }
    events.each do |event|
      ActiveSupport::Notifications.notifier.listeners_for("#{event}.#{component}").each do |listener|
        if listener.instance_variable_get('@delegate') == subscriber
          ActiveSupport::Notifications.unsubscribe listener
        end
      end
    end
  end
end

# Make sure it has a logger just in case
ActiveRecord::Base.logger = Lines.logger


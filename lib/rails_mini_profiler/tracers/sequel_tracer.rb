# frozen_string_literal: true

module RailsMiniProfiler
  module Tracers
    class SequelTracer < Tracer
      class << self
        def subscribes_to
          'sql.active_record'
        end

        def build_from(event)
          new(event).trace
        end

        def presents
          SequelTracePresenter
        end
      end

      def trace
        return NullTrace.new if ignore?

        payload = @event[:payload].slice(:name, :sql, :binds, :type_casted_binds)
        typecasted_binds = payload[:type_casted_binds]
        # Sometimes, typecasted binds are a proc. Not sure why. In those instances, we extract the typecasted
        # values from the proc by executing call.
        typecasted_binds = typecasted_binds.call if typecasted_binds.respond_to?(:call)
        payload[:binds] = transform_binds(payload[:binds], typecasted_binds)
        payload.delete(:type_casted_binds)
        payload.reject { |_k, v| v.blank? }
        @event[:payload] = payload
        super
      end

      private

      def transform_binds(binds, type_casted_binds)
        binds.each_with_object([]).with_index do |(binding, object), i|
          name = if binding.respond_to?(:name)
                   binding.name
                 elsif binding.is_a?(String)
                   binding
                 else
                   binding.to_s
                 end
          value = type_casted_binds[i]
          object << { name: name, value: value }
        end
      end

      def ignore?
        payload = @event[:payload]
        !SqlTracker.new(name: payload[:name], query: payload[:sql]).track?
      end
    end
  end
end

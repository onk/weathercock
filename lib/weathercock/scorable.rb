# frozen_string_literal: true

module Weathercock
  module Scorable
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def weathercock_scorer
        @weathercock_scorer ||= Scorer.new(klass: self)
      end

      def top(event, limit:, decay_factor: nil, **window)
        weathercock_scorer.top(event, limit: limit, decay_factor: decay_factor, **window)
      end

      def hit_counts(event, ids:, **window)
        weathercock_scorer.hit_counts(event, ids: ids, **window)
      end
    end

    def hit(event, increment: 1)
      self.class.weathercock_scorer.hit(id, event, increment: increment)
    end

    def hit_count(event, **window)
      self.class.weathercock_scorer.hit_count(id, event, **window)
    end

    def remove_hits(event)
      self.class.weathercock_scorer.remove_hits(id, event)
    end
  end
end

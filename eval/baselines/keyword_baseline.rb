module Eval
  module Baselines
    class KeywordBaseline
      PRIORITY_CUES = {
        "P1" => %w[global enterprise-wide company-wide all customers all employees outage unavailable crashed down stopped çöktü kesintisi herkes tüm şirket acil urgent critical],
        "P2" => %w[department region several multiple intermittent partially gecikiyor yavaş partial],
        "P4" => %w[non-urgent not urgent no issue resolved typo cosmetic single user one user tek kullanıcı teşekkür typo]
      }.freeze

      HUMAN_CUES = %w[unclear unknown security-sensitive duplicate possible potential major injection scope unclear prompt]

      def self.call(record)
        text = "#{record.fetch('short_description')} #{record.fetch('description')}".downcase
        priority = if PRIORITY_CUES.fetch("P1").any? { |cue| text.include?(cue) }
                     "P1"
        elsif PRIORITY_CUES.fetch("P2").any? { |cue| text.include?(cue) }
                     "P2"
        elsif PRIORITY_CUES.fetch("P4").any? { |cue| text.include?(cue) }
                     "P4"
        else
                     "P3"
        end

        {
          "priority" => priority,
          "needs_human" => HUMAN_CUES.any? { |cue| text.include?(cue) }
        }
      end
    end
  end
end

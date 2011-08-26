module Meetings
  module Helpers
    
    # Simple class to compute the start and end dates of a calendar
    class Calendar
      include Redmine::I18n
      attr_reader :startdt, :enddt
      
      def initialize(date, lang = current_language, period = :month)
        @date = date
        @events = []
        @ending_meetings_by_days = {}
        @starting_meetings_by_days = {}
        set_language_if_valid lang        
        case period
        when :month
          @startdt = DateTime.civil(date.year, date.month, 1)
          @enddt = (@startdt >> 1)-1
          # starts from the first day of the week
          @startdt = @startdt - (@startdt.cwday - first_wday)%7
          # ends on the last day of the week
          @enddt = @enddt + (last_wday - @enddt.cwday)%7
        when :week
          @startdt = date - (date.cwday - first_wday)%7
          @enddt = date + (last_wday - date.cwday)%7
        when :day
          @startdt = DateTime.civil(date.year, date.month, date.day, 0, 0, 0)
          @enddt = @startdt + 1
        else
          raise 'Invalid period'
        end
      end
      
      # Sets calendar meetings
      def meetings=(meetings)
        @meetings = meetings
        @ending_meetings_by_days = @meetings.group_by {|meeting| meeting.end_date.to_date}
        @starting_meetings_by_days = @meetings.group_by {|meeting| meeting.start_date.to_date}
      end
      
      # Returns events for the given day
      def meetings_on(day)
        ((@ending_meetings_by_days[day] || []) + (@starting_meetings_by_days[day] || [])).uniq.sort_by {|meeting| meeting.start_date}
      end
      
      # Calendar current month
      def month
        @date.month
      end
      
      # Return the first day of week
      # 1 = Monday ... 7 = Sunday
      def first_wday
        case Setting.start_of_week.to_i
        when 1
          @first_dow ||= (1 - 1)%7 + 1
        when 6
          @first_dow ||= (6 - 1)%7 + 1
        when 7
          @first_dow ||= (7 - 1)%7 + 1
        else
          @first_dow ||= (l(:general_first_day_of_week).to_i - 1)%7 + 1
        end
      end
      
      def last_wday
        @last_dow ||= (first_wday + 5)%7 + 1
      end
    end    
  end
end

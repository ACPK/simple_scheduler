module SimpleScheduler
  # A Time class for parsing the :at option on a task into the first time it should run.
  #   Time.now
  #   # => 2016-12-09 08:24:11 -0600
  #   SimpleScheduler::At.new("*:30")
  #   # => 2016-12-09 08:30:00 -0600
  #   SimpleScheduler::At.new("1:00")
  #   # => 2016-12-10 01:00:00 -0600
  #   SimpleScheduler::At.new("Sun 0:00")
  #   # => 2016-12-11 00:00:00 -0600
  class At < Time
    AT_PATTERN = /(Sun|Mon|Tue|Wed|Thu|Fri|Sat)?\s?(?:\*{1,2}|(\d{1,2})):(\d{1,2})/
    DAYS = %w(Sun Mon Tue Wed Thu Fri Sat).freeze

    # Accepts a time string to determine when a task should be run for the first time.
    # Valid formats:
    #   "18:00"
    #   "3:30"
    #   "**:00"
    #   "*:30"
    #   "Sun 2:00"
    #   "[Sun|Mon|Tue|Wed|Thu|Fri|Sat] 00:00"
    # @param at [String] The formatted string for a task's run time
    # @param time_zone [ActiveSupport::TimeZone] The time zone to parse the at time in
    def initialize(at, time_zone = Time.zone)
      @at = at
      @time_zone = time_zone
      super(parsed_time.year, parsed_time.month, parsed_time.day,
            parsed_time.hour, parsed_time.min, parsed_time.sec, parsed_time.utc_offset)
    end

    # Always returns the specified hour if the hour was given, otherwise
    # it returns the hour calculated based on other specified options.
    # @return [Integer]
    def hour
      hour? ? at_hour : super
    end

    # Returns whether or not the hour was specified in the :at string.
    # @return [Boolean]
    def hour?
      at_match[2].present?
    end

    private

    def at_match
      @at_match ||= AT_PATTERN.match(@at) || []
    end

    def at_hour
      @at_hour ||= (at_match[2] || now.hour).to_i
    end

    def at_min
      @at_min ||= (at_match[3] || now.min).to_i
    end

    def at_wday
      @wday ||= DAYS.index(at_match[1])
    end

    def at_wday?
      at_match[1].present?
    end

    def next_hour?
      !hour? && at_min < now.min
    end

    def now
      @now ||= @time_zone.now.beginning_of_minute
    end

    def parsed_day
      parsed_day = now.beginning_of_day

      # If no day of the week is given, return today
      return parsed_day unless at_wday?

      # Shift to the correct day of the week if given
      add_days = at_wday - parsed_day.wday
      add_days += 7 if parsed_day.wday > at_wday
      parsed_day + add_days.days
    end

    # Returns the very first time a job should be run for the scheduled task.
    # @return [Time]
    def parsed_time
      return @parsed_time if @parsed_time

      @parsed_time = parsed_day
      change_hour = at_hour

      # Add an additional hour if a specific hour wasn't given, if the minutes
      # given are less than the current time's minutes.
      change_hour += 1 if next_hour?
      @parsed_time = @parsed_time.change(hour: change_hour, min: at_min)

      # If the parsed time is still before the current time, add an additional day if
      # the week day wasn't specified or add an additional week to get the correct time.
      @parsed_time += at_wday? ? 1.week : 1.day if now > @parsed_time
      @parsed_time
    end
  end
end

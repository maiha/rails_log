class RailsLog::Parser
  include Enumerable

  class << self
    def import(log_file, options = {})
      buffer = File.read(log_file)
      buffer = NKF.nkf(options[:nkf].to_s, buffer) unless options[:nkf].blank?
      buffer.gsub!(/\e\[(\d+(;\d+)*)m/, '') # delete escapes

      klass = RailsLog
      klass.transaction do
        counter = 0
        last_imported_at = klass.maximum(:time).to_i
        new(buffer).each do |access|
          next unless last_imported_at < access[:time].to_i
          klass.create! access
          counter += 1
        end
        return counter
      end
    end
  end

  def initialize(log)
    @log = log
  end

  def each(&block)
    @log.scan(/\n\n(.*?)(\n\n|\Z)/m){ yield parse($1) }
  end

  private
    def parse(log)
      returning @hash = {:log=>log} do
        log.each_line do |line| parse_line(line.chomp) end
      end
    end

    def parse_line(line)
      # Processing ToppageController#index (for 59.157.184.25 at 2007-03-16 05:52:55) [GET]
      #   Session ID: 7dd61b5ae1fc75fec0627603f605afc8
      #   Parameters: {"sitetype"=>"0", "action"=>"index", "controller"=>"toppage"}
      # Rendering toppage/index
      # Completed in 0.16765 (5 reqs/sec) | Rendering: 0.02143 (12%) | DB: 0.12256 (73%) | 200 OK [http://...]
      case line
      when /^Processing (.*?)Controller#(.*?) \(for (.*?) at (.*?)\) \[(.*?)\]$/
        @hash[:controller] = $1
        @hash[:action]     = $2
        @hash[:address]    = $3
        @hash[:time]       = Time.mktime(*ParseDate.parsedate($4)[0,6])
        @hash[:scheme]     = $5
      when /^  Session ID: (.*?)$/
        @hash[:session_id] = $1
      when /^  Parameters: (.*?)$/
        @hash[:parameters] = strip_controller_and_action($1.to_s)
      when /^Completed in ([\d\.]+) /
        @hash[:runtime]    = $1.to_f
        benchmark     = $'.to_s
        parse_runtime(:rd, :Rendering, benchmark)
        parse_runtime(:db, :DB,        benchmark)
        parse_status(benchmark)
      when /\(500 Internal Error\)$/
        @hash[:status] = 500
        parse_else(line)
      else
        parse_else(line)
      end
    end

    def parse_status(line)
      case line
      when %r{\\| (\d+)\s+[^|]+\s+\[.*?\]$}
        @hash[:status] = $1.to_i
      end
    end

    def parse_runtime(key, label, line)
      if %r{ \\| #{label}: ([\d\.]+) \((\d+)%\)} === line.to_s
        @hash[:"#{key}_runtime"] = $1.to_f
        @hash[:"#{key}_percent"] = [$2.to_i, 100].min
      end
    end

    def parse_else(line)
      # nop
    end

    def strip_controller_and_action(string)
      string.gsub!(/"(action|controller)"=>".*?"/, '')
      string.gsub!(/,\s*,/, ',')
      string.gsub!(/^\{\*,/, '{')
      string.gsub!(/,\s*\}$/, '}')
      return string
    end

end

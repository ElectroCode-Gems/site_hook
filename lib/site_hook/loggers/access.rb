module SiteHook
  module Loggers
    class Access
      def initialize(klass)
        @@loggers = {
            stdout: ::Logger.new(STDOUT, progname: klass),
            stderr: ::Logger.new(STDERR, progname: klass),
            file: ::Logger.new(SiteHook::Paths.make_log_name(klass), progname: klass)
        }
        @@loggers.each do |_logger, obj|
          obj.datetime_format = '%Y-%m-%dT%H:%M:%S%Z'
          obj.formatter       = proc do |severity, datetime, progname, msg|
            "#{severity} [#{datetime}] #{progname} —— #{msg}\n"
          end
        end
      end

      def self.unknown(obj)
        @@loggers.each do |_key, value|
          value.unknown(obj)
        end
      end

      def self.error(obj)
        @@loggers.each do |_key, value|
          value.error(obj)
        end
      end

      def self.info(obj)
        @@loggers.each do |_key, value|
          next if key == :stderr
          value.info(obj)
        end
      end

      def self.fatal(obj)
        @@loggers.each do |key, value|
          next if key == :stderr
          value.fatal(obj)
        end
      end

      def self.warn(obj)
        @@loggers.each do |_key, value|
          value.warn(obj)
        end
      end

      # @param [Symbol] level log level to log at
      # @param [Object] obj some kind of object or msg to log
      def self.log(level, obj)
        @@loggers.each do |logger|
          logger.add(@levels[level], obj)
        end
      end

      def self.log_raw(msg)
        @@loggers.each do |logger|
          logger.<<(obj)
        end

      end
    end
  end
end

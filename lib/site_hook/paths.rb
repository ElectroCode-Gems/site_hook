##########
# -> File: /home/ken/RubymineProjects/site_hook/lib/site_hook/paths.rb
# -> Project: site_hook
# -> Author: Ken Spencer <me@iotaspencer.me>
# -> Last Modified: 1/10/2018 21:23:00
# -> Copyright (c) 2018 Ken Spencer
# -> License: MIT
##########
require 'site_hook/methods'
require 'site_hook/exceptions'
require 'site_hook/version'
module SiteHook
  # Paths: Paths to gem resources and things
  class Paths
    def self.old_dir
      Pathname(Dir.home).join('.jph')
    end
    def self.old_config
      Pathname(Dir.home).join('.jph', 'config')
    end
    def self.old_logs
      Pathname(Dir.home).join('.jph', 'logs')
    end
    def self.dir
      Pathname(Dir.home).join('.shrc')
    end
    def self.config
      Pathname(Dir.home).join('.shrc', 'config')
    end

    def self.logs
      Pathname(Dir.home).join('.shrc', 'logs')
    end
    def self.default_config(old_exists = self.old_config.exist?, new_exists = self.config.exist?)
      path = ''
      begin 
        if old_exists
          path = self.old_config
        else
          if new_exists
            path = self.config
          else
            raise SiteHook::NeitherConfigError.new path
          end
        end
      rescue SiteHook::NeitherConfigError
        path = self.config
      end
      path
    end
    def self.default_logs(old_exists = self.old_logs.exist?, new_exists = self.logs.exist?)
      path = ''
      begin 
        if old_exists
          path = self.old_logs
        else
          if new_exists
            path = self.logs
          else
            raise SiteHook::NoLogsError.new path
          end
        end
      rescue SiteHook::NoLogsError
        path = self.logs
      end
      path
    end

    def self.lib_dir
      if ENV['BUNDLE_GEMFILE']
        Pathname(ENV['BUNDLE_GEMFILE']).dirname.join('lib')
      else
        Pathname(::Gem.user_dir).join('gems', "site_hook-#{SiteHook::VERSION}", 'lib')
      end

    end
    def self.make_log_name(klass, level = nil, old_exists = self.old_logs.exist?, new_exists = self.logs.exist?)
      if level
        level = "-#{level}"
      end
      case old_exists
      when true
        path = self.old_logs
        self.old_logs.join("#{klass.to_s.safe_log_name}#{level}.log")
      when false
        if new_exists
          self.logs.join("#{klass.to_s.safe_log_name}#{level}.log")
        else
          path ||= SiteHook::Paths.logs
          raise SiteHook::NoLogsError.new path
        end

      end
    rescue Errno::ENOENT => e

    end
  end
end

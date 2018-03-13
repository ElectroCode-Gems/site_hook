require 'open3'
require 'site_hook/logger'

module SiteHook
  module Senders
    class Jekyll
      class Build
        attr :jekyll_source, :build_dest

        # @param [String,Pathname] jekyll_source Path
        # @param [String,Pathname] build_dest path
        def initialize(jekyll_source, build_dest, logger:)
          @jekyll_source = jekyll_source
          @build_dest = build_dest
          @log = logger
        end

        def grab_jekyll_version
          begin
            stdout_str, stderr_str, status = Open3.capture3('jekyll --version')
          rescue Errno::ENOENT
            @log.log.error('Jekyll not installed! Gem and Webhook will not function')
          end
        end

        def build
          stdout_str, stderr_str, status = Open3.capture3("jekyll build --source #{@jekyll_source} --destination #{Pathname(@build_dest).to_path}")
        end
      end

      def self.build
        instance = self.Build.new
        #instance.
      end
    end
  end
end

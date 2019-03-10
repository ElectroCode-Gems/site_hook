##########
# -> File: /home/ken/RubymineProjects/site_hook/lib/site_hook/webhook.rb
# -> Project: site_hook
# -> Author: Ken Spencer <me@iotaspencer.me>
# -> Last Modified: 1/10/2018 21:35:44
# -> Copyright (c) 2018 Ken Spencer
# -> License: MIT
##########
require 'scorched'
require 'rack'
require 'site_hook/logger'
require 'json'
module SiteHook
  class Server < Scorched::Controller
    config[:logger]                = false
    config[:show_exceptions] = true
    config[:show_http_error_pages] = true
    middleware << proc do
      use Rack::Static, :url => ['public']
    end
    render_defaults[:dir]    = SiteHook::Paths.lib_dir.join('site_hook', 'views').to_s
    render_defaults[:layout] = :layout
    render_defaults[:engine] = :haml
    config[:static_dir]      = Pathname(SiteHook::Paths.lib_dir).join('site_hook', 'assets', 'public').to_s

    #
    # @param [String] body JSON String of body
    # @param [String] sig Signature or token from git service
    # @param [String] secret User-defined verification token
    # @param [Boolean] plaintext Whether the verification is plaintext
    # @param [String] service service name
    def self.verified?(body, sig, secret, plaintext:, service:)
      if plaintext
        sig == secret
      else
        case service
        when 'gogs'
          if sig == OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, secret, body)
            SiteHook::Log.app.debug "Secret verified: #{sig} === #{OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, secret, body)}"
            true
          end
        when 'github'
          if sig == OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA1.new, secret, body)
            SiteHook::Log.app.debug "Secret verified: #{sig} === #{OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA1.new, secret, body)}"
            true
          end
        else
          # This shouldn't happen
        end
      end
    end

    APPLICATION_JSON = 'application/json'
    before do
      remote_addr      = request.env['REMOTE_ADDR']
      cf_connecting_ip = request.env.fetch('HTTP_CF_CONNECTING_IP', nil)
      ip               = cf_connecting_ip || remote_addr
      SiteHook::Log.access.log "#{ip} - #{request.path}:"
    end
    after do
      SiteHook::Log.access.log "#{response.status}"
    end
    get '/' do
      render :not_found
    end
    controller '/webhook' do
      post '/' do
        halt 403
      end
      get '/:hook_name' do
        project = SiteHook::Config.projects.find_project(captures[:hook_name])
        if project.nil?
          render :maybe_private
        else
          render :webhook, locals: {project: project}
        end

      end
      post '/:hook_name' do
        content_type APPLICATION_JSON
        service = nil
        request.body.rewind
        req_body = request.body.read
        project  = SiteHook::Config.projects.find_project(captures[:hook_name])
        if project.nil?
          halt 404, {message: 'no such project', status: 1}.to_json
        end
        plaintext = false
        signature = nil
        event     = nil
        gogs      = request.env.fetch('HTTP_X_GOGS_EVENT', nil)
        unless gogs.nil?
          event = 'push' if gogs == 'push'
        end
        github = request.env.fetch('HTTP_X_GITHUB_EVENT', nil)
        unless github.nil?
          event = 'push' if github == 'push'
        end
        gitlab = request.env.fetch('HTTP_X_GITLAB_EVENT', nil)
        unless gitlab.nil?
          event = 'push' if gitlab == 'push'
        end

        events = {'github' => github, 'gitlab' => gitlab, 'gogs' => gogs}
        if events['github'] && events['gogs']
          events['github'] = nil
        end
        events_m_e = events.values.one?
        case events_m_e
        when true
          event   = 'push'
          service = events.select { |_key, value| value }.keys.first
        when false
          halt 400,
               {CONTENT_TYPE: APPLICATION_JSON},
               {message: 'events are mutually exclusive', status: 'failure'}.to_json

        else
          halt 400,
               {CONTENT_TYPE: APPLICATION_JSON},
               {'status': 'failure', 'message': 'something weird happened'}
        end
        if event != 'push' && event.nil?
          halt 400,
               {CONTENT_TYPE: APPLICATION_JSON},
               {message: 'no event header', status: 'failure'}.to_json
        end
        case service
        when 'gitlab'
          signature = request.env.fetch('HTTP_X_GITLAB_TOKEN', '')
          plaintext = true
        when 'github'
          signature = request.env.fetch('HTTP_X_HUB_SIGNATURE', '').sub!(/^sha1=/, '')
          plaintext = false

        when 'gogs'
          signature = request.env.fetch('HTTP_X_GOGS_SIGNATURE', '')
          plaintext = false
        else
          # This shouldn't happen
        end
        if Server.verified?(req_body.to_s, signature, project['hookpass'], plaintext: plaintext, service: service)
          SiteHook::Log.build.info 'Building...'
          begin
            jekyll_status = SiteHook::Senders::Jekyll.build(project['src'], project['dst'], SiteHook::Log.Build, options: {config: project['config']})
            case jekyll_status

            when 0
              status 200
              headers CONTENT_TYPE => APPLICATION_JSON
              body { {'status': 'success'}.to_json }
            when -1, -2, -3
              halt 400, {CONTENT_TYPE => APPLICATION_JSON}, {'status': 'exception', error: jekyll_status.fetch(:message).to_s}
            else
              # This shouldn't happen
            end
          rescue => e
            halt 500, {CONTENT_TYPE => APPLICATION_JSON}, {'status': 'exception', error: e.to_s}
          end
        else
          halt 403, {CONTENT_TYPE => APPLICATION_JSON}, {message: 'incorrect secret', 'status': 'failure'}.to_json
        end
      end
    end
    controller '/webhooks' do
      get '/' do
        render :webhooks, locals: {'projects' => SiteHook::Config.projects}
      end

    end
  end
end

require 'tinder'
require 'git_reflow/service'

module GitReflow
  module Services
    class Campfire < GitReflow::Service
      def self.required_credentials
        {
          :subdomain => "The name of your Campfire account (usually your subdomain)",
          :token     => "Your authentication token"
        }
      end

      def self.name
        "Campfire"
      end

      def send_update(message = "", room = "")

      end

      def self.setup
        self.subdomain = ask "Please enter your Campfire subdomain: "
        self.token     = ask "Please enter your Campfire token: "

        begin
          @campfire ||= Tinder::Campfire.new self.subdomain, :token => self.token, :ssl_options => {:verify => false}
        rescue Tinder::AuthenticationFailed => authentication_error
          puts "Your account could not be authenticated.  Please setup your account again with 'git reflow hooks setup campfire'"
          return nil
        end

        if @campfire
          puts "Campfire account setup successfully!"
          @campfire.rooms.first.speak "GitReflow in the house!! :joy:"
          puts "A message was sent to the #{@campfire.rooms.first.name}"
        else
          exit_now! "We were unable to setup campfire.  Check your subdomain and api key and try again."
        end
      end

      def self.setup?
        found_all_required = false
        required_credentials.each do |key, value|
          found_all_required = `git config --global --get reflow.hooks.campfire.#{key}`.present?
          break unless found_all_required
        end

        return found_all_required
      end

      def self.subdomain
        `git config --global --get reflow.hooks.campfire.subdomain`.strip
      end

      def self.subdomain=(campfire_subdomain)
        `git config --global --replace-all reflow.hooks.campfire.subdomain #{campfire_subdomain}`
      end

      def self.token
        `git config --global --get reflow.hooks.campfire.token`.strip
      end

      def self.token=(campfire_token)
        `git config --global --replace-all reflow.hooks.campfire.token #{campfire_token}`
      end

      def self.campfire
        return nil unless setup?
        @campfire
      end
    end
  end
end

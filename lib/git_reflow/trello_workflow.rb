require 'trello'

module GitReflow
  module TrelloWorkflow
    extend self

    def setup
      if GitReflow::Config.get('trello.api-key').length <= 0
        GitReflow.say "Visit: https://trello.com/app-key"
        trello_key = ask("Enter your Developer API Key found on the URL above: ")
        GitReflow::Config.set('trello.api-key', trello_key)
        GitReflow.say "Visit: https://trello.com/1/authorize?key=#{trello_key}&response_type=token&expiration=never&scope=read,write&name=GitReflow"
        trello_member_key = ask("Enter your Member Token generated from the URL above: ")
        GitReflow::Config.set('trello.member-token', trello_member_key)
      end

      @trello_member_token ||= Trello.configure do |config|
        config.developer_public_key = GitReflow::Config.get('trello.api-key')
        config.member_token         = GitReflow::Config.get('trello.member-token')
      end

      begin
        @trello_member_id ||= Trello::Token.find(@trello_member_token).member_id
        GitReflow::Config.set('trello.member-id', @trello_member_id, local: true)
        # Ensure defaults are setup
        GitReflow::Config.set('trello.next-list-id', 'Next', local: true) unless GitReflow::Config.get('trello.next-list-id', local: true).length > 0
        GitReflow::Config.set('trello.current-list-id', 'In Progress', local: true) unless GitReflow::Config.get('trello.current-list-id', local: true).length > 0
        GitReflow::Config.set('trello.staged-list-id', 'Staged', local: true) unless GitReflow::Config.get('trello.staged-list-id', local: true).length > 0
        GitReflow::Config.set('trello.approved-list-id', 'Approved', local: true) unless GitReflow::Config.get('trello.approved-list-id', local: true).length > 0
        GitReflow::Config.set('trello.completed-list-id', 'Live', local: true) unless GitReflow::Config.get('trello.completed-list-id', local: true).length > 0

        unless GitReflow::Config.get('trello.board-id', local: true).length > 0
          board_for_this_project = ask("Enter the name of the Trello board for this project: ")
          GitReflow::Config.set('trello.board-id', board_for_this_project, local: true)
        end
      rescue Trello::Error => e
      end

      @trello_member_token
    end

    def current_trello_member
      begin
        @trello_member ||= Trello::Member.find GitReflow::Config.get('trello.member-id')
      rescue Trello::Error => e
        nil
      end
    end

    def current_trello_card_id
      GitReflow::Config.get("branch.#{current_branch}.trello-card-id")
    end

    def current_trello_card
      return nil unless using_trello?
      begin
        Trello::Card.find(current_trello_card_id)
      rescue Trello::Error
        nil
      end
    end

    def trello_lists
      begin
        @trello_lists ||= Trello::Board.find(GitReflow::Config.get('trello.board-id', local: true)).lists
      rescue Trello::Error
        begin
          matching_board = Trello::Board.all.select {|b| b.name.downcase == GitReflow::Config.get('trello.board-id', local: true)}.first
          if matching_board.present?
            GitReflow::Config.set('trello.board-id', matching_board.id, local: true)
            @trello_lists = matching_board.lists
          else
            []
          end
        rescue Trello::Error
          []
        end
      end
    end

    def trello_uses_list?(list_name)
      !GitReflow::Config.get("trello.#{list_name}-list-id", local: true).empty?
    end

    def trello_list(key)
      trello_lists.select {|l| l.name == GitReflow::Config.get("trello.#{key}-list-id", local: true) }.first
    end

    def trello_next_list
      @trello_next_list ||= trello_list('next')
    end

    def trello_in_progress_list
      @trello_current_list ||= trello_list('current')
    end

    def trello_staged_list
      @trello_staged_list ||= trello_list('staged')
    end

    def trello_approved_list
      @trello_approved_list ||= trello_list('approved')
    end

    def trello_completed_list
      @trello_completed_list ||= trello_list('completed')
    end

  end
end

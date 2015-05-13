desc 'Start will create a new feature branch and setup remote tracking'
long_desc <<LONGTIME
  Performs the following:\n
  \t$ git pull origin <current_branch>\n
  \t$ git push origin <current_branch>:refs/heads/[new_feature_branch]\n
  \t$ git checkout --track -b [new_feature_branch] origin/[new_feature_branch]\n
LONGTIME
arg_name '[new-feature-branch-name] - name of the new feature branch'
command :start do |c|
  c.desc 'Use an existing trello card as a reference'
  c.switch :trello

  c.desc 'Describe a flag to list'
  c.default_value 'default'
  c.flag :f
  c.action do |global_options, options, args|
    if options[:trello]
      Trello.configure do |config|
        config.developer_public_key = GitReflow::Config.get('trello.api-key')
        config.member_token         = GitReflow::Config.get('trello.member-token')
      end
      # Gather Next cards
      next_list = Trello::Board.find(GitReflow::Config.get('trello.board-id', local: true)).lists.select {|l| l.name == GitReflow::Config.get('trello.list-id', local: true) }.first
      unless next_list.nil?
        selected = choose do |menu|
          menu.prompt = "Choose a task to start: "

          next_list.cards.first(5).each do |card|
            menu.choice("#{card.name} [#{card.id}] -- #{card.list_id}")
          end
        end
        puts "Starting card ##{selected[/\[\w+\]/][1..-2]}"
      end
    elsif args.empty?
      raise "usage: git-reflow start [new-branch-name]"
    else
      `git pull origin #{GitReflow.current_branch}`
      `git push origin #{GitReflow.current_branch}:refs/heads/#{args[0]}`
      `git checkout --track -b #{args[0]} origin/#{args[0]}`
    end
  end
end

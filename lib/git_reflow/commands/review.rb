desc 'review will push your latest feature branch changes to your remote repo and create a pull request'
arg_name 'Describe arguments to review here'
command :review do |c|
  c.desc 'push your latest feature branch changes to your remote repo and create a pull request against the destination branch'
  c.arg_name '[destination_branch] - the branch you want to merge your feature branch into'
  c.flag [:t, :title], default_value: 'last commit message'
  c.flag [:m, :message], default_value: 'title'
  c.switch [:e, :edit]
  c.action do |global_options,options,args|

    commit_msg_file = '/tmp/git_reflow_pr_msg'

    if global_options[:title] || global_options[:message]
      review_options = {
        'base' => args[0],
        'title' => (global_options[:title]   || GitReflow.current_branch),
        'body' =>  (global_options[:message] || GitReflow.get_first_commit_message)
      }
      editor = false
    else # if edit flag or nothing is provided, open editor
      editor = true
    end

    if options[:edit] # if edit we inject title & body into file before opening
      File.open(commit_msg_file, 'w') do |file|
        file.write(GitReflow.current_branch)
        file.write("\n")
        file.write(GitReflow.get_first_commit_message)
      end
    end

    if editor
      system('nano', commit_msg_file)
      pr_msg = File.open(commit_msg_file).each_line.map(&:strip).to_a
      title = pr_msg.shift
      File.delete(commit_msg_file)
      review_options = {'base' => args[0],'title' => title,'body' =>  pr_msg.join("\n")}
    end

    puts "\nReview your PR:\n"
    puts "--------\n"
    puts "Title:\n#{review_options['title']}\n\n"
    puts "Body:\n#{review_options['body']}\n"
    puts "--------\n"
    puts "Submit PR? (Y/n):"
    exit 0 if STDIN.gets.chop.downcase =~ /n/
    GitReflow.review review_options
  end
end

# ruleid:mass-assignment-protection-disabled
User.new(params[:user], :without_protection => true)

# ok:mass-assignment-protection-disabled
User.new(params[:user])
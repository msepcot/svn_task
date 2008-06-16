namespace :svn do
  
  desc "Add new files (svn status of '?') to the Subversion repository."
  task :add do
    files = `svn status`.split("\n").find_all{ |f| f =~ /^\?/ }.collect { |f| f.split()[1] }
    puts `svn add #{files.join(" ")} --force` unless files.empty?
  end
  
  desc "Commit files to the Subversion repository. Add comments with \"rake svn:commit m='message'\" or \"rake svn:commit comment='message'\". Performs svn:add and svn:delete to get a complete commit, svn:update to get the latest code and check for conflicts and runs the rake test tasks to ensure a clean commit."
  task :commit => [:add, :delete, :update] do
    comment = ENV['comment'] || ENV['m']
    comment = '[rake svn:commit with no comment]' if not comment or '' == comment
    puts `svn commit -m '#{comment}'`
  end
  
  desc "Remove deleted files (svn status of '!') from the Subversion repository."
  task :delete do
    files = `svn status`.split("\n").find_all{ |f| f =~ /^\!/ }.collect { |f| f.split()[1] }
    puts `svn delete #{files.join(" ")} --force` unless files.empty?
  end
  
  desc "Show the status of your local files as compared to the Subversion repository."
  task :status do
    files = `svn status`.split("\n")
    
    modified = files.grep /^M/
    puts "", "Changed Files", "-------------------------", modified unless modified.empty?
    files = files - modified
    
    added = files.grep /^(A|\?)/
    puts "", "Files to Add", "-------------------------", added unless added.empty?
    files = files - added
    
    deleted = files.grep /^(D|!)/
    puts "", "Files to Delete", "-------------------------", deleted unless deleted.empty?
    files = files - deleted
    
    puts "", "UNKNOWN ACTION", "-------------------------", files unless files.empty?
    puts ""
  end
  
  desc "Update files from the Subversion repository, migrate the database, and run rake tests."
  task :update do
    files = `svn up`
    puts files
    raise "One or more conflicts found." unless files.grep(/^C/).empty?
    Rake::Task["db:migrate"].invoke
    Rake::Task[:test].invoke
  end
  
  desc "Setup a new Rails project for Subversion."
  task :setup do
    # Rename database.yml to database.example.yml
    if File.exists? 'config/database.yml'
      move 'config/database.yml', 'config/database.example.yml'
    end
    
    # Remove all files in the 'log' and 'tmp' directories as well as the the .sqlite3 files in 'db'
    files = Dir.glob('log/*') + Dir.glob('tmp/*') + Dir.glob('db/*.sqlite3')
    files.each { |file| remove_entry file }
    
    # Create 'doc/api' and 'doc/app' directories
    mkdir_p ['doc/api', 'doc/app']
    
    # Freeze to the current version of rails
    Rake::Task["rails:freeze:gems"].invoke
    Rake::Task["rails:update"].invoke
    
    # Add all files to subversion
    Rake::Task["svn:add"].invoke
    
    # Commit the files to subversion
    `svn commit -m "Initial checkin with frozen rails"`
    
    # svn:ignore
    `svn propset svn:ignore "database.yml" config/`
    `svn propset svn:ignore "*" log/`
    `svn propset svn:ignore "*" tmp/`
    `svn propset svn:ignore "*" doc/app/`
    `svn propset svn:ignore "*" doc/api/`
    `svn propset svn:ignore "*.sqlite3" db/`
    
    # Commit the propsets
    `svn commit -m "Initial svn:ignore list - config/database.yml log/* tmp/* doc/app/* doc/api/* db/*.sqlite3"`
  end

end
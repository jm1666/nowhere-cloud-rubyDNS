namespace :db do
  desc 'Run migrations'
  task :migrate, [:version] do |_, args|
    require 'sequel'
    require 'dotenv'

    Dotenv.load

    Sequel.extension :migration
    db = Sequel.connect(ENV.fetch('DATABASE_URL'))
    if args[:version]
      puts 'Migrating to version #{args[:version]}'
      Sequel::Migrator.run(db, 'migrations', target: args[:version].to_i)
    else
      puts 'Migrating to latest'
      Sequel::Migrator.run(db, 'migrations')
    end
  end
end

namespace :config do
  desc 'Create dotenv config file'
  task :create do
    cp('.env.example', '.env')
  end
end

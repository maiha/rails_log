namespace :rails_log do

    desc "Install rails_log files into application directory"
    task :install do
      require 'fileutils'
      src = File.dirname(__FILE__) + "/../files/*"
      dst = File.dirname(__FILE__) + "/../../../../"
      FileUtils.cp_r Dir.glob(src), dst, :verbose=>true
    end

    desc "Uninstall rails_log files from application directory"
    task :uninstall do
      require 'fileutils'
      root = File.dirname(__FILE__) + "/../../../../"
      dst  = root + "app/controllers/rails_log_controller.rb"
      FileUtils.rm dst, :verbose=>true if File.exist?(dst)
    end

    task :add_indexes => :environment do
      ActiveRecord::Schema.define do
        table_name = RailsLog.table_name
        add_index table_name,  :time
        add_index table_name,  :address
        add_index table_name,  :session_id
        add_index table_name,  :status
        add_index table_name,  :scheme
      end
    end

    task :remove_indexes => :environment do
      ActiveRecord::Schema.define do
        table_name = RailsLog.table_name
        remove_index table_name,  :time
        remove_index table_name,  :address
        remove_index table_name,  :session_id
        remove_index table_name,  :status
        remove_index table_name,  :scheme
      end
    end

    desc "Create 'rails_logs' table for log analyzer"
    task :create => :environment do
      ActiveRecord::Schema.define do
        table_name = RailsLog.table_name
        create_table table_name, :force => true do |t|
          t.column :time,      :datetime
          t.column :scheme,    :string
          t.column :controller,:string
          t.column :action,    :string
          t.column :address,   :string
          t.column :parameters,:string
          t.column :session_id,:string
          t.column :runtime,   :float
          t.column :rd_runtime,:float
          t.column :rd_percent,:integer
          t.column :db_runtime,:float
          t.column :db_percent,:integer
          t.column :status,    :integer,  :default=>0
          t.column :log,       :text
        end
      end
      Rake::Task["rails_log:add_indexes"].invoke
    end

    desc "Drop analyzer table (rails_logs)"
    task :drop => :environment do
      ActiveRecord::Schema.define do
        table_name = RailsLog.table_name
        drop_table table_name
      end
    end

    desc "Clear analyzer table (rails_logs)"
    task :clear => :environment do
      RailsLog.delete_all
    end

    desc "Import rails log data from log file"
    task :import => :environment do
      log_file = ARGV[1] || "log/#{RAILS_ENV}.log"

      puts "importing rails log from #{log_file} ..."
      start = Time.now
      count = RailsLog::Parser.import(log_file, :nkf=>"-w")
      puts "%d entries are imported. (%dsec)" % [count, (Time.now-start)]
    end

end

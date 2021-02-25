require 'pry-rails'
namespace :csv do
  desc "create a new file with unique identifiers"
  task :inspect, [:csv_file, :matching_type] => :environment do |t, args|
    inspector = CsvInspector.new
    matching_type = args.matching_type || "phone_or_email"
    puts "Uploading CSV to system to search for dupliates based on #{matching_type.gsub('_',' ')}"
    file_name = inspector.find_duplicates(args.csv_file,args.matching_type)
    puts "New CSV generated at #{file_name}"
    `open #{file_name}`
  end
end

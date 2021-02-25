require 'rails_helper'

RSpec.describe CsvInspector, type: :model do
  let (:csv_1) {"spec/files/input1.csv"}
  let (:csv_2) {"spec/files/input2.csv"}
  let (:csv_3) {"spec/files/input3.csv"}
  let (:inspector) {CsvInspector.new}

  it "uploads to csv table" do
    table_name = inspector.table_name(csv_1)
    expect{inspector.upload_csv_to_table(csv_1, table_name)}.to_not raise_error
    table = ActiveRecord::Base.connection.table_exists? table_name
    expect(table).to equal(true)
    unique_ids =  ActiveRecord::Base.connection.select_values(%Q{
        SELECT unique_identifier FROM #{table_name}
    })
    expect(unique_ids.count).to eq(8)
  end

  it "normalizes phone data" do
    table_name = inspector.table_name(csv_1)
    inspector.upload_csv_to_table(csv_1, table_name)
    expect{inspector.normalize_phone_data(table_name)}.to_not raise_error
    phones =  ActiveRecord::Base.connection.select_values(%Q{
        SELECT phone1 FROM #{table_name}
    })

    expect(phones.compact.count).to eq(6)
    expect(phones.last.size).to eq(11)
    expect(phones.last.gsub("\D",'').size).to eq(11)
  end

  describe "csv 1" do
    before(:each) do
      @table_name = inspector.table_name(csv_1)
      inspector.upload_csv_to_table(csv_1, @table_name)
      inspector.normalize_phone_data(@table_name)
    end

    it "matches by email" do
      expect{inspector.match_by_email(@table_name)}.to_not raise_error
      duplicates = ActiveRecord::Base.connection.select_values(%Q{
          SELECT unique_identifier FROM #{@table_name}
          WHERE email1 = 'janes@home.com'
      })
      expect(duplicates).to eq(["2","2"])
    end

    it "matches by phone" do
      expect{inspector.match_by_phone(@table_name)}.to_not raise_error
      duplicates = ActiveRecord::Base.connection.select_values(%Q{
          SELECT unique_identifier FROM #{@table_name}
          WHERE phone1 = '15551234567'
      })
      expect(duplicates).to eq(["2","2"])
    end

    it "matches by phone or email" do
      expect{inspector.match_by_email(@table_name)}.to_not raise_error
      expect{inspector.match_by_phone(@table_name)}.to_not raise_error
      duplicates = ActiveRecord::Base.connection.select_values(%Q{
          SELECT unique_identifier FROM #{@table_name}
          WHERE phone1 = '15551234567'
          OR email1 = 'janes@home.com'
      })
      expect(duplicates).to eq(["2","2","2"])
    end
  end

  describe "csv 2" do
    before(:each) do
      @table_name = inspector.table_name(csv_2)
      inspector.upload_csv_to_table(csv_2, @table_name)
      inspector.normalize_phone_data(@table_name)
    end

    it "matches by email" do
      expect{inspector.match_by_email(@table_name)}.to_not raise_error
      duplicates = ActiveRecord::Base.connection.select_values(%Q{
          SELECT unique_identifier FROM #{@table_name}
          WHERE email1 = 'jackd@home.com'
          OR email2 = 'jackd@home.com'
      })
      expect(duplicates).to eq(["4","4","4"])

      other_duplicates = ActiveRecord::Base.connection.select_values(%Q{
          SELECT unique_identifier FROM #{@table_name}
          WHERE email1 = 'johnd@home.com'
          OR email2 = 'johnd@home.com'
      })
      expect(other_duplicates).to eq(["1","1"])
    end

    it "matches by phone" do
      expect{inspector.match_by_phone(@table_name)}.to_not raise_error
      duplicates = ActiveRecord::Base.connection.select_values(%Q{
          SELECT unique_identifier FROM #{@table_name}
          WHERE id in (1,2,3,4)
      })
      expect(duplicates).to eq(["1","1","1","1"])
    end

    it "matches by phone and email" do
      expect{inspector.match_by_email(@table_name)}.to_not raise_error
      expect{inspector.match_by_phone(@table_name)}.to_not raise_error
      duplicates = ActiveRecord::Base.connection.select_values(%Q{
          SELECT unique_identifier FROM #{@table_name}
          WHERE id in (1,2,3,4,5)
      })
      expect(duplicates).to eq(["1","1","1","1","1"])
    end
  end
end

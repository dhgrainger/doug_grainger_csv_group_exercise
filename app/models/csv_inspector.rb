require 'csv'

class CsvInspector
  def table_name(csv)
    table_name = csv.split('/').last.split('.').first
  end

  def modified_file_name(table_name, matching_type)
    Rails.root + "tmp/" + "#{table_name}_matched_by_#{matching_type}.csv"
  end

  def upload_csv_to_table(csv, table_name)
    headers = CSV.read(csv, headers: true).headers.map(&:downcase)
    copy_columns = headers.join(', ')
    column_names = (["unique_identifier"] + headers)
    unless (column_names & ["phone2", "email2"]).any? # add email2 and phone2 if they are not there
      column_names = column_names + ["phone2", "email2"]
    end

    #create a data table for the csv dump
    ActiveRecord::Migration.execute("DROP TABLE IF EXISTS #{table_name}")
    ActiveRecord::Migration.create_table table_name do |t|
      column_names.each do |col|
        t.string col
      end
    end

    #copy data from csv
    ActiveRecord::Base.connection.execute(%Q{
      COPY #{table_name}(#{copy_columns}) FROM '#{Rails.root + csv}' DELIMITER ',' CSV HEADER
    })

    #normalize email and phone column names
    if (column_names & ["email","phone"]).any?
      ActiveRecord::Migration.execute(%Q{
        AlTER TABLE #{table_name}
        RENAME COLUMN email TO email1;
        AlTER TABLE #{table_name}
        RENAME COLUMN phone TO phone1
      })
    end

    #seed initial unique_identifiers based on the id
    ActiveRecord::Base.connection.execute(%Q{
      UPDATE #{table_name}
      SET unique_identifier = id
    })
  end

  def normalize_phone_data(table_name)
    #strip out non digits from phone numbers
    ActiveRecord::Base.connection.execute(%Q{
      UPDATE #{table_name}
      SET
        phone1 = REGEXP_REPLACE(phone1, '\\D', '', 'g'),
        phone2 = REGEXP_REPLACE(phone2, '\\D', '', 'g')
    })

    #add country code to phone numbers without it
    ActiveRecord::Base.connection.execute(%Q{
      UPDATE #{table_name}
      SET phone1 = CONCAT('1', phone1)
      WHERE LENGTH(phone1) < 11
      AND phone1 IS NOT NULL
    })

    #Do same for phone 2
    ActiveRecord::Base.connection.execute(%Q{
      UPDATE #{table_name}
      SET phone2 = CONCAT('1', phone2)
      WHERE LENGTH(phone2) < 11
      AND phone2 IS NOT NULL
    })
  end

  #give entries with matching emails the first entry with that email unique identifier
  def match_by_email(table_name)
    ActiveRecord::Base.connection.execute(%Q{
        UPDATE #{table_name} t1
        SET
          unique_identifier = dups.unique_identifier
        FROM
          (
            SELECT t.unique_identifier, sub.email,
            row_number() over (partition by trim(coalesce(sub.email,''))) as row
            FROM #{table_name} t
            LEFT JOIN LATERAL (
              SELECT id, email
              FROM (VALUES (t.email1),(t.email2)) s(email)
            ) sub USING(ID)
          ) dups
        WHERE dups.row > 1
        AND (dups.email IS NOT NULL)
        AND (dups.email = t1.email1 OR dups.email = t1.email2)
      })
  end

  #give entries with matching emails the first entry with that email unique identifier
  def match_by_phone(table_name)
    ActiveRecord::Base.connection.execute(%Q{
        UPDATE #{table_name} t1
        SET
          unique_identifier = dups.unique_identifier
        FROM
          (
            SELECT unique_identifier, sub.phone,
            row_number() over (partition by sub.phone) as row
            from #{table_name} t
            LEFT JOIN LATERAL (
              SELECT id, phone
              FROM (VALUES (t.phone1),(t.phone2)) s(phone)
            ) sub USING(ID)
          ) dups
        WHERE dups.row > 1
        AND (dups.phone IS NOT NULL)
        AND (dups.phone = t1.phone1 OR dups.phone = t1.phone2)
    })
  end

  #Write the modified table to a csv
  def ouput_table_to_csv(table_name, matching_type)
    file_name = modified_file_name(table_name, matching_type)
    ActiveRecord::Base.connection.execute(%Q{
      COPY #{table_name} TO '#{file_name}' DELIMITER ',' CSV HEADER;
    })
    file_name #make this the last line so we can pass it back to the rake task to tell the user
  end

  #time to call all the other methods
  def find_duplicates(csv, matching_type)
    table_name = table_name(csv)
    upload_csv_to_table(csv, table_name)
    normalize_phone_data(table_name)
    match_by_email(table_name) if ['email', 'phone_or_email'].include?(matching_type)
    match_by_phone(table_name) if ['phone', 'phone_or_email'].include?(matching_type)
    file_name = ouput_table_to_csv(table_name, matching_type)
  end
end

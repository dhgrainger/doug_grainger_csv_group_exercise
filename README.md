# README

SPECIFICATIONS:

The goal of this exercise is to identify rows in a CSV file that may represent the same person based on a provided Matching Type (definition below).

The resulting program should allow us to test at least three matching types:

one that matches records with the same email address
one that matches records with the same phone number
one that matches records with the same email address OR the same phone number

Output

The expected output is a copy of the original CSV file with the unique identifier of the person each row represents prepended to the row.

LOCAL SETUP

Ruby Version: 2.5.1
Postgresql Version: 11.1

git clone

createdb dg_codesample_dev
createdb dg_codesample_test

bundle install

rake db:migrate
rake db:test_prepare

INSTRUCTIONS

To run tests rspec spec/models/csv_inspector.rb

To run the task

rake csv:inspect['file_name','matching_type']

Where file name is a csv and matching can be 'email', 'phone', 'phone_or_email'

REFERENCES

https://www.enterprisedb.com/postgres-tutorials/how-import-and-export-data-using-csv-files-postgresql

https://stackoverflow.com/questions/2594829/finding-duplicate-values-in-a-sql-table

https://stackoverflow.com/questions/41366183/how-to-combine-values-from-multiple-columns-and-remove-any-duplicates-using-tran

https://stackoverflow.com/questions/35413355/postgresql-left-join-lateral-is-too-slow-than-subquery

Sequel.migration do
  up do
    create_table(:dns_records, ignore_index_errors: true) do
      primary_key :id
      String :type, size: 4, null: false
      String :name, size: 64, null: false
      String :ipv4address, size: 15, null: true
      String :ipv6address, size: 39, null: true
      String :cname, size: 255, null: true

      index [:ipv4address], name: :ipv4address
      index [:ipv6address], name: :ipv6address
      index [:name], name: :name
    end
  end

  down do
    drop_table(:records)
  end
end

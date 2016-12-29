Sequel.migration do
  up do
    create_table(:records, ignore_index_errors: true) do
      primary_key :id
      String :name, size: 64, null: false
      String :ipv4address, size: 15, null: false
      String :ipv6address, size: 39, null: false

      index [:ipv4address], name: :ipv4address
      index [:ipv6address], name: :ipv6address
      index [:name], name: :name
    end
  end

  down do
    drop_table(:records)
  end
end

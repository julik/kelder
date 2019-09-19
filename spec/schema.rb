ActiveRecord::Schema.define(:version => 1) do
  create_table :things do |t|
    t.string :description, :null => true
    t.timestamps :null => false
  end
end

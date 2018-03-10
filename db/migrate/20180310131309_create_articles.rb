class CreateArticles < ActiveRecord::Migration[5.0]
  def change
    create_table :articles do |t|
      t.string :url
      t.string :date
      t.text :en_title
      t.text :en_body
      t.text :ja_title
      t.text :ja_body
      t.timestamps
    end
  end
end

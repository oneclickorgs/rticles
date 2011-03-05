class CreateParagraphs < ActiveRecord::Migration
  def self.up
    create_table :paragraphs do |t|
      t.text 'body'
      t.integer 'position'
      t.integer 'parent_id'
      t.integer 'document_id'
      t.timestamps
    end
  end

  def self.down
    drop_table :paragraphs
  end
end

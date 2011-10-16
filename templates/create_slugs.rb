class CreateSlugs < ActiveRecord::Migration
  def change
    create_table :slugs do |t|
      t.belongs_to :sluggable, polymorphic: true, null: false
      t.boolean :active, null: false, default: true
      t.string :slug, null: false, limit: 126
      t.string :scope, limit: 126
      t.datetime :created_at
    end
    
    change_table :slugs do |t|
      t.index [ :sluggable_type, :sluggable_id, :active ], name: 'slugs_for_record'
      t.index [ :sluggable_type, :scope, :slug ], unique: true, name: 'slugs_unique'
    end
  end
end

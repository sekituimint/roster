class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t| #=> この引数名「:sensors」がテーブル名になる
      t.string :name
      t.integer :groupid
      t.integer :order
      t.string :email
      t.timestamps  #=> この一行でcreated_atとupdated_atのカラムが定義される
    end
  end
end

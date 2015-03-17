class CreateSweepers < ActiveRecord::Migration
  def change
    create_table :groups do |t| #=> この引数名「:sensors」がテーブル名になる
      t.string :name
      t.string :mini
      t.integer :interval
      t.integer :renew
      t.integer :noworder
      t.timestamps  #=> この一行でcreated_atとupdated_atのカラムが定義される
    end
  end
end

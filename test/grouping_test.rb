require "test/unit"
require 'active_record'

class CreateCustomers < ActiveRecord::Migration
  def up
    create_table :customers do |t|
      t.string :name
    end
  end

  def down
    drop_table :customers
  end
end

class CreateOrdersUngrouped < ActiveRecord::Migration
  def up
    create_table :orders do |t|
      t.date :odate
    end
  end

  def down
    drop_table :orders
  end
end

class CreateOrdersGrouped < ActiveRecord::Migration
  def up
    create_table :orders do |t|
      t.date :odate
      t.references :customers, grouping: true
    end
  end

  def down
    drop_table :orders
  end
end

class ChangeOrdersAddReference < ActiveRecord::Migration
  def up
    change_table :orders do |t|
      t.references :customers
    end
  end

  def down
    change_table :orders do |t|
      t.remove_references :customers
    end
  end
end

class AddOrdersGrouping < ActiveRecord::Migration
  def up
    add_grouping :orders, :customers
  end

  def down
    remove_grouping :orders
  end
end

class ChangeOrdersAddReferenceGrouping < ActiveRecord::Migration
  def up
    change_table :orders do |t|
      t.references :customers, grouping: true
    end
  end

  def down
    change_table :orders do |t|
      t.remove_references :customers
    end
  end
end

class ChangeOrdersAddGrouping < ActiveRecord::Migration
  def up
    change_table :orders do |t|
      t.add_grouping :customers
    end
  end

  def down
    change_table :orders do |t|
      t.remove_grouping
    end
  end
end

class ChangeOrdersAddGroupingNewStyle < ActiveRecord::Migration
  def change
    change_table :orders do |t|
      reversible do |dir|
        dir.up    { t.add_grouping :customers }
        dir.down  { t.remove_grouping }
      end
    end
  end
end


class GroupingTest < Test::Unit::TestCase

  TEST_SCHEMA = 'activerecord_unittest'

  def setup
    ActiveRecord::Base.establish_connection(:adapter  => 'fdbsql',
                                            :database => TEST_SCHEMA,
                                            :host     => 'localhost',
                                            :port     => '15432',
                                            :username => 'test',
                                            :password => '')
    ActiveRecord::Base.connection.recreate_database TEST_SCHEMA
  end

  def get_parent_and_child
    ActiveRecord::Base.connection.select_rows <<-SQL
      SELECT tc.table_name parent,
             gc.constraint_table_name child
      FROM information_schema.grouping_constraints gc
      INNER JOIN information_schema.table_constraints tc
        ON  gc.unique_schema=tc.table_schema
        AND gc.unique_constraint_name=tc.constraint_name
      WHERE
        gc.unique_schema='#{TEST_SCHEMA}'
    SQL
  end

  def expect_grouped
    assert_equal [['customers', 'orders']], get_parent_and_child
  end

  def expect_ungrouped
    assert_equal [], get_parent_and_child
  end

  def create_ungrouped
    CreateCustomers.new.up
    CreateOrdersUngrouped.new.up
  end

  def create_grouped
    CreateCustomers.new.up
    CreateOrdersGrouped.new.up
  end


  def test_create_ungrouped
    create_ungrouped
    expect_ungrouped
  end

  def test_create_grouped
    create_grouped
    expect_grouped
  end

  def test_add_grouping
    create_ungrouped
    ChangeOrdersAddReference.new.up
    AddOrdersGrouping.new.up
    expect_grouped
  end

  def test_remove_grouping
    create_grouped
    AddOrdersGrouping.new.down
    expect_ungrouped
  end

  def test_change_orders_add_reference_grouping
    create_ungrouped
    ChangeOrdersAddReferenceGrouping.new.up
    expect_grouped
  end

  def test_change_orders_remove_reference_grouping
    create_grouped
    ChangeOrdersAddReferenceGrouping.new.down
    expect_ungrouped
  end

  def test_change_orders_add_grouping
    create_ungrouped
    ChangeOrdersAddReference.new.up
    ChangeOrdersAddGrouping.new.up
    expect_grouped
  end

  def test_change_orders_remove_grouping
    create_grouped
    ChangeOrdersAddGrouping.new.down
    expect_ungrouped
  end

  def test_change_orders_add_grouping_new_style
    return skip "new style migrations require Rails 4" unless ActiveRecord::VERSION::MAJOR >= 4
    create_ungrouped
    ChangeOrdersAddReference.new.up
    ChangeOrdersAddGroupingNewStyle.migrate :up
    expect_grouped
  end

  def test_change_orders_remove_grouping_new_style
    return skip "new style migrations require Rails 4" unless ActiveRecord::VERSION::MAJOR >= 4
    create_grouped
    ChangeOrdersAddGroupingNewStyle.migrate :down
    expect_ungrouped
  end

end


#
# FoundationDB SQL Layer ActiveRecord Adapter
# Copyright (c) 2013-2014 FoundationDB, LLC
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

require 'fdbsql_test_helper'

# Ensure task gets registered
require './lib/activerecord-fdbsql-adapter'

class CreateTaskTest < TEST_CASE_BASE
  def setup
    @connection    = stub(:create_database => true)
    @configuration = {
      'adapter'  => 'fdbsql',
      'database' => 'my_test_schema'
    }
    ActiveRecord::Base.stubs(:connection).returns(@connection)
    ActiveRecord::Base.stubs(:establish_connection).returns(true)
  end

  def test_establishes_connection_to_internal_schema
    ActiveRecord::Base.expects(:establish_connection).with(
      'adapter'   => 'fdbsql',
      'database'  => 'fdbsql'
    )
    ActiveRecord::Tasks::DatabaseTasks.create @configuration
  end

  def test_creates_database_with_default_charset_collation
    @connection.expects(:create_database).with('my_test_schema', @configuration.merge('charset' => 'UTF8', 'collation' => 'ucs_binary'))
    ActiveRecord::Tasks::DatabaseTasks.create @configuration
  end

  def test_creates_database_with_given_charset
    @connection.expects(:create_database).with('my_test_schema', @configuration.merge('charset' => 'latin', 'collation' => 'ucs_binary'))
    ActiveRecord::Tasks::DatabaseTasks.create @configuration.merge('charset' => 'latin')
  end

  def test_creates_database_with_given_collation
    @connection.expects(:create_database).with('my_test_schema', @configuration.merge('charset' => 'UTF8', 'collation' => 'en_us'))
    ActiveRecord::Tasks::DatabaseTasks.create @configuration.merge('collation' => 'en_us')
  end

  def test_establishes_connection_to_new_database
    ActiveRecord::Base.expects(:establish_connection).with(@configuration)
    ActiveRecord::Tasks::DatabaseTasks.create @configuration
  end

  def test_db_create_with_error_prints_message
    ActiveRecord::Base.stubs(:establish_connection).raises(Exception)
    $stderr.stubs(:puts).returns(true)
    $stderr.expects(:puts).with("Couldn't create database for #{@configuration.inspect}")
    ActiveRecord::Tasks::DatabaseTasks.create @configuration
  end

  def test_create_when_database_exists_outputs_info_to_stderr
    $stderr.expects(:puts).with("my_test_schema already exists").once
    ActiveRecord::Base.connection.stubs(:create_database).raises(
      ActiveRecord::StatementInvalid.new('Schema "my_test_schema" already exists')
    )
    ActiveRecord::Tasks::DatabaseTasks.create @configuration
  end
end

class DropTaskTest < TEST_CASE_BASE
  def setup
    @connection    = stub(:drop_database => true)
    @configuration = {
      'adapter'  => 'fdbsql',
      'database' => 'my_test_schema'
    }
    ActiveRecord::Base.stubs(:connection).returns(@connection)
    ActiveRecord::Base.stubs(:establish_connection).returns(true)
  end

  def test_establishes_connection_to_internal_schema
    ActiveRecord::Base.expects(:establish_connection).with(
      'adapter'   => 'fdbsql',
      'database'  => 'fdbsql'
    )
    ActiveRecord::Tasks::DatabaseTasks.drop @configuration
  end

  def test_drops_database
    @connection.expects(:drop_database).with('my_test_schema')
    ActiveRecord::Tasks::DatabaseTasks.drop @configuration
  end
end

class PurgeTaskTest < TEST_CASE_BASE
  def setup
    @connection    = stub(:create_database => true, :drop_database => true)
    @configuration = {
      'adapter'  => 'fdbsql',
      'database' => 'my_test_schema'
    }
    ActiveRecord::Base.stubs(:connection).returns(@connection)
    ActiveRecord::Base.stubs(:clear_active_connections!).returns(true)
    ActiveRecord::Base.stubs(:establish_connection).returns(true)
  end

  def test_clears_active_connections
    ActiveRecord::Base.expects(:clear_active_connections!)
    ActiveRecord::Tasks::DatabaseTasks.purge @configuration
  end

  def test_establishes_connection_to_internal_schema
    ActiveRecord::Base.expects(:establish_connection).with(
      'adapter'   => 'fdbsql',
      'database'  => 'fdbsql',
    )
    ActiveRecord::Tasks::DatabaseTasks.purge @configuration
  end

  def test_drops_database
    @connection.expects(:drop_database).with('my_test_schema')
    ActiveRecord::Tasks::DatabaseTasks.purge @configuration
  end

  def test_creates_database
    @connection.expects(:create_database).with('my_test_schema', @configuration.merge('charset' => 'UTF8', 'collation' => 'ucs_binary'))
    ActiveRecord::Tasks::DatabaseTasks.purge @configuration
  end

  def test_establishes_connection
    ActiveRecord::Base.expects(:establish_connection).with(@configuration)
    ActiveRecord::Tasks::DatabaseTasks.purge @configuration
  end
end

class StructureDumpTaskTest < TEST_CASE_BASE
  def setup
    @connection    = stub(:structure_dump => true)
    @configuration = {
      'adapter'  => 'fdbsql',
      'database' => 'my_test_schema'
    }
    ActiveRecord::Base.stubs(:connection).returns(@connection)
    ActiveRecord::Base.stubs(:establish_connection).returns(true)
    Kernel.stubs(:system)
  end

  def test_structure_dump
    filename = "awesome-file.sql"
    Kernel.expects(:system).with("fdbsqldump --no-data --output #{filename} my_test_schema").returns(true)
    ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
  end
end

class StructureLoadTaskTest < TEST_CASE_BASE
  def setup
    @connection    = stub
    @configuration = {
      'adapter'  => 'fdbsql',
      'database' => 'my_test_schema'
    }
    ActiveRecord::Base.stubs(:connection).returns(@connection)
    ActiveRecord::Base.stubs(:establish_connection).returns(true)
    Kernel.stubs(:system)
  end

  def test_structure_load
    filename = "awesome-file.sql"
    Kernel.expects(:system).with("fdbsqlcli --quiet --file #{filename} my_test_schema")
    ActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
  end
end


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

require 'shellwords'

module ActiveRecord

  module Tasks

    class FdbSqlDatabaseTasks

      delegate :connection, :establish_connection, :clear_active_connections!,
        to: ActiveRecord::Base

      def initialize(configuration)
        @configuration = configuration
      end

      def create
        # NB: Relies on being able to connect to non-existing schema
        establish_connection configuration.merge('database' => 'fdbsql')
        # TODO: Pass options (e.g. default character set) when available
        connection.create_database configuration['database']
      rescue ActiveRecord::StatementInvalid => error
        if /Schema .* already exists/ === error.message
          raise DatabaseAlreadyExists
        else
          raise
        end
      end

      def drop
        establish_connection
        connection.drop_database configuration['database']
      end

      def encoding
        connection.encoding
      end

      def charset
        connectionc.charset
      end

      def collation
        connection.collation
      end

      def purge
        clear_active_connections!
        drop
        create true
      end

      def structure_dump(filename)
        set_fdbsql_env
        command = "fdbsqldump --no-data --output #{Shellwords.escape(filename)} #{Shellwords.escape(configuration['database'])}"
        raise 'Error dumping database' unless Kernel.system(command)
      end

      def structure_load(filename)
        set_fdbsql_env
        Kernel.system("fdbsqlcli --quiet --file #{Shellwords.escape(filename)} #{configuration['database']}")
      end


      private

        def configuration
          @configuration
        end

        def set_fdbsql_env
          ENV['FDBSQL_HOST'] = configuration['host'] if configuration['host']
          ENV['FDBSQL_PORT'] = configuration['port'].to_s if configuration['port']
          ENV['FDBSQL_USER'] = configuration['username'].to_s if configuration['username']
          ENV['FDBSQL_PASSWORDD'] = configuration['password'].to_s if configuration['password']
        end

    end

  end

end


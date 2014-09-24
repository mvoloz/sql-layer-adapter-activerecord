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

      DEFAULT_CHARSET = ENV['CHARSET'] || 'UTF8'
      DEFAULT_COLLATION = ENV['COLLATION'] || 'ucs_binary'

      delegate :connection, :establish_connection, :clear_active_connections!,
        to: ActiveRecord::Base

      def initialize(configuration)
        @configuration = configuration
      end

      def create
        # NB: Relies on being able to connect to non-existing schema
        establish_connection configuration.merge('database' => 'fdbsql')
        connection.create_database configuration['database'], create_options
        establish_connection configuration
      rescue ActiveRecord::StatementInvalid => error
        if /Schema .* already exists/ === error.message
          raise DatabaseAlreadyExists
        else
          raise
        end
      end

      def drop
        # NB: Relies on being able to connect to non-existing schema
        establish_connection configuration.merge('database' => 'fdbsql')
        connection.drop_database configuration['database']
      end

      def charset
        connection.charset
      end

      def collation
        connection.collation
      end

      def purge
        clear_active_connections!
        drop
        create
      end

      def structure_dump(filename)
        args = make_arg_array('fdbsqldump')
        args << '--no-data' << '--output' << filename << configuration['database']
        kernel_system('dump', args)
      end

      def structure_load(filename)
        args = make_arg_array('fdbsqlload')
        args << '--quiet' << '--schema' << configuration['database'] << filename
        kernel_system('load', args)
      end


      private

        def configuration
          @configuration
        end

        def create_options
          cs = configuration['charset'] || configuration['encoding'] || DEFAULT_CHARSET
          co = configuration['collation'] || DEFAULT_COLLATION
          configuration.merge('charset' => cs, 'collation' => co)
        end

        def make_arg_array(program)
          args = [ program ]
          args << '--host' << configuration['host'] if configuration['host']
          args << '--port' << configuration['port'].to_s if configuration['port']
          args << '--user' << configuration['user'] if configuration['user']
          args << '--password' << configuration['password'] if configuration['password']
          return args
        end

        def kernel_system(desc, args)
          unless Kernel.system(*args)
            $stderr.puts "Could not #{desc} the database structure. "\
                "Make sure `#{args[0]}` is in your PATH and check the command output for warnings."
          end
        end

    end

  end

end


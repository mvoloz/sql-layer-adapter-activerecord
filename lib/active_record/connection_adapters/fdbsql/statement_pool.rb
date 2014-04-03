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

module ActiveRecord

  module ConnectionAdapters

    class FdbSqlAdapter < AbstractAdapter

      class FdbSqlStatementPool < StatementPool

        def initialize(connection, max)
          super
          @count = 0
          @cache = Hash.new { |h,pid| h[pid] = {} }
        end

        def each(&block)
          cache.each(&block)
        end

        def key?(key)
          cache.key?(key)
        end

        def [](key)
          cache[key]
        end

        def length
          cache.length
        end

        def []=(sql, key)
          while @max <= cache.size
            dealloc(cache.shift.last)
          end
          @count += 1
          cache[sql] = key
        end

        def clear
          cache.each_value do |k|
            dealloc k
          end
          cache.clear
        end

        def delete(sql_key)
          dealloc cache[sql_key]
          cache.delete sql_key
        end


        # FdbSql =================================================

        def next_key
          "ar_#{@count + 1}"
        end

        def cache
          @cache[$$]
        end

        def dealloc(key)
          @connection.query "DEALLOCATE #{key}" if connection_active?
        end

        def connection_active?
          @connection.status == PGconn::CONNECTION_OK
        rescue PGError
          false
        end

      end

    end

  end

end


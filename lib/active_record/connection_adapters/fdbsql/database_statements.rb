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

      module DatabaseStatements

        # Returns an array of arrays containing the field values
        # Order is the same as that returned by +columns+
        if ArVer::GTEQ_4_0_4
          def select_rows(sql, name = nil, binds = [])
            exec_query(sql, name, binds).rows
          end
        else
          def select_rows(sql, name = nil, binds = [])
            select_raw(sql, name).last
          end
        end

        # Executes the SQL statement in the context of this connection.
        def execute(sql, name = nil)
          exec_no_cache(sql, name, nil)
        end

        # Executes +sql+ statement in the context of this connection using
        # +binds+ as the bind substitutes. +name+ is logged along with
        # the executed +sql+ statement.
        def exec_query(sql, name = nil, binds = [])
          result = without_prepared_statement?(binds) ? exec_no_cache(sql, name, binds) :
                                                        exec_cache(sql, name, binds)
          result_array = result_as_array(result)
          if ArVer::GTEQ_4
            column_types = compute_field_types(result)
            ret = ActiveRecord::Result.new(result.fields, result_array, column_types)
          else
            ret = ActiveRecord::Result.new(result.fields, result_array)
          end
          result.clear
          ret
        end

        # Executes delete +sql+ statement in the context of this connection using
        # +binds+ as the bind substitutes. +name+ is the logged along with
        # the executed +sql+ statement.
        def exec_delete(sql, name = nil, binds = [])
          result = without_prepared_statement?(binds) ? exec_no_cache(sql, name, binds) :
                                                        exec_cache(sql, name, binds)
          affected = result.cmd_tuples
          result.clear
          affected
        end
        alias :exec_update :exec_delete

        if ArVer::LT_4
          # Checks whether there is currently no transaction active. This is done
          # by querying the database driver, and does not use the transaction
          # house-keeping information recorded by #increment_open_transactions and
          # friends.
          #
          # Returns true if there is no transaction active, false if there is a
          # transaction active, and nil if this information is unknown.
          def outside_transaction?
            @connection.transaction_status == PGconn::PQTRANS_IDLE
          end
        end

        # Returns +true+ when the connection adapter supports prepared statement
        # caching, otherwise returns +false+
        def supports_statement_cache?
          true
        end

        # Begins the transaction (and turns off auto-committing).
        def begin_db_transaction
          execute("BEGIN")
        end

        # Commits the transaction (and turns on auto-committing).
        def commit_db_transaction
          execute("COMMIT")
        end

        # Rolls back the transaction (and turns on auto-committing). Must be
        # done if the transaction block raises an exception or returns false.
        def rollback_db_transaction
          execute("ROLLBACK")
        end

        # Implemented in schema_statements
        #def default_sequence_name(table, column)
        #end

        # Set the sequence to the max value of the table's column.
        def reset_sequence!(table, column, sequence = nil)
          # Nobody else implements this and it isn't called from anywhere
        end

        def empty_insert_statement_value
          "VALUES(DEFAULT)"
        end


        # OTHER METHODS ============================================

        # Won't be called unless adapter claims supports_explain?
        def explain(arel, binds = [])
          sql = "EXPLAIN #{to_sql(arel, binds)}"
          exec_query(sql, 'EXPLAIN', binds)
        end


        protected

          # Returns an array of record hashes with the column names as keys and
          # column values as values.
          # As of 4.1.0: Returns an ActiveRecord::Result instance.
          def select(sql, name = nil, binds = [])
            ret = exec_query(sql, name, binds)
            ArVer::GTEQ_4 ? ret : ret.to_a
          end

          # (Executes an INSERT and)
          # Returns the last auto-generated ID from the affected table.
          def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
            return super if id_value
            pk = pk_from_insert_sql(sql) unless pk
            select_value("#{sql} RETURNING #{quote_column_name(pk)}")
          end
          alias :create :insert_sql

          # Executes an UPDATE query and returns the number of affected tuples.
          def delete_sql(sql, name = nil)
            result = execute(sql, name)
            result.cmd_tuples
          end
          alias :update_sql :delete_sql

          def sql_for_insert(sql, pk, id_value, sequence_name, binds)
            pk = pk_from_insert_sql(sql) unless pk
            sql = "#{sql} RETURNING #{quote_column_name(pk)}" if pk
            [sql, binds]
          end


        private

          STALE_STATEMENT_CODE = '0A50A'


          def exec_no_cache(sql, name, binds)
            log(sql, name, binds) {
              @connection.async_exec(sql)
            }
          end

          def exec_cache(sql, name, binds)
            is_retry = false
            begin
              stmt_key = prepare_stmt(sql)
              casted_binds = binds.map { |col, val| [ col, type_cast(val, col) ] }
              casted_values = casted_binds.map { |_, val| val }
              # Only log on first pass otherwise tests expecting certain query counts (may) fail
              if is_retry
                begin
                  exec_cache_internal(stmt_key, casted_values)
                rescue e
                  raise translate_exception(e)
                end
              else
                log(sql, name, ArVer::GTEQ_4_1 ? casted_binds : binds) do
                  exec_cache_internal(stmt_key, casted_values)
                end
              end
            rescue StalePreparedStatement
              @statements.delete(sql_cache_key(sql))
              @logger.debug('Retrying last statement') if @logger
              is_retry = true
              retry
            end
          end

          def exec_cache_internal(stmt_key, bind_values)
            @connection.send_query_prepared(stmt_key, bind_values)
            @connection.block()
            @connection.get_last_result()
          end

          def result_as_array(res)
            # Any binary columns need un-escaped
            binaries = []
            res.nfields.times { |i|
              binaries << i if res.ftype(i) == TypeID::BLOB
            }
            rows = res.values
            return rows unless binaries.any?
            rows.each { |row|
              binaries.each { |i|
                row[i] = unescape_binary(row[i])
              }
            }
          end

          def select_raw(sql, name = nil)
            res = execute(sql, name)
            results = result_as_array(res)
            fields = res.fields
            res.clear
            return fields, results
          end

          # Super gross but insert APIs require returning the generated ID
          def pk_from_insert_sql(sql)
            sql[/into\s+([^\(]*).*values\s*\(/i]
            primary_key($1.strip) if $1
          end

          def sql_cache_key(sql)
            "#{stmt_cache_prefix}-#{sql}"
          end

          def prepare_stmt(sql)
            sql_key = sql_cache_key(sql)
            unless @statements.key? sql_key
              nkey = @statements.next_key
              begin
                @connection.prepare nkey, sql
              rescue => e
                raise translate_exception_class(e, sql)
              end
              # Clear the queue
              @connection.get_last_result
              @statements[sql_key] = nkey
            end
            @statements[sql_key]
          end

          def compute_field_types(result)
            types = {}
            result.fields.each_with_index { |name, i|
              types[name] = fetch_type(name, result.ftype(i), result.fmod(i))
            }
            types
          end

      end

    end

  end

end


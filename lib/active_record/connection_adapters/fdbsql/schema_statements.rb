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

      module SchemaStatements

        # Returns a Hash of mappings from the abstract data types to the native
        # database types. See TableDefinition#column for details on the recognized
        # abstract data types.
        def native_database_types
          NATIVE_DATABASE_TYPES
        end

        # Returns true if table exists.
        # If the schema is not specified as part of +name+ then it will only find tables within
        # the current schema search path (regardless of permissions to access tables in other schemas)
        def table_exists?(table_name)
          return false unless table_name
          schema, table = split_table_name(table_name)
          tables(nil, schema, table).any?
        end

        # Returns an array of indexes for the given table.
        def indexes(table_name, name = nil)
          select_rows(
            "SELECT index_name, "+
            "       is_unique "+
            "FROM information_schema.indexes "+
            "WHERE table_schema = CURRENT_SCHEMA "+
            "  AND table_name = '#{quote_string(table_name.to_s)}' "+
            "  AND index_type <> 'PRIMARY' "+
            "ORDER BY index_name",
            name || SCHEMA_LOG_NAME
          ).map { |row|
            cols = select_rows(
              "SELECT column_name "+
              "FROM information_schema.index_columns "+
              "WHERE index_table_schema = CURRENT_SCHEMA "+
              "  AND index_table_name = '#{quote_string(table_name.to_s)}' "+
              "  AND index_name = '#{quote_string(row[0])}' "+
              "ORDER BY ordinal_position",
              name || SCHEMA_LOG_NAME
            ).map { |col_row|
              col_row[0]
            }
            IndexDefinition.new(table_name, row[0], row[1] == 'YES', cols, [], {})
          }
        end

        # Returns an array of Column objects for the table specified by +table_name+.
        # See the concrete implementation for details on the expected parameter values.
        def columns(table_name, name = nil)
          type_part = @sql_layer_version >= 10903 ?
            " COLUMN_TYPE_STRING(table_schema, table_name, column_name), " :
            " data_type||COALESCE('('||character_maximum_length||')', '('||numeric_precision||','||numeric_scale||')', ''), "
          select_rows(
            "SELECT column_name, "+
            "       column_default, "+
                    type_part +
            "       is_nullable "+
            "FROM information_schema.columns "+
            "WHERE table_schema = CURRENT_SCHEMA "+
            "  AND table_name = '#{quote_string(table_name.to_s)}' "+
            "ORDER BY ordinal_position",
            name || SCHEMA_LOG_NAME
          ).map { |row|
            # Base Column depends on lower and no space (e.g. DECIMAL(10, 0) => decimal(10,0))
            type_str = row[2].gsub(' ', '').downcase
            FdbSqlColumn.new(row[0], row[1], type_str, row[3] == 'YES')
          }
        end

        # Returns the sequence name for the table specified by +table_name+.
        def default_sequence_name(table_name, column = nil)
          pk, seq = pk_and_sequence_for(table_name)
          if column && (pk != column)
            # Is this ever actually called with a non-pk column?
            nil
          else
            seq
          end
        rescue
          nil
        end

        # Renames a table
        def rename_table(old_name, new_name)
          execute(
            "RENAME TABLE #{quote_table_name(old_name)} TO #{quote_table_name(new_name)}",
            SCHEMA_LOG_NAME
          )
          # TODO: Rename sequence when syntax is supported
          if ActiveRecord::VERSION::MAJOR >= 4
            rename_table_indexes(old_name, new_name)
          end
        end

        if ActiveRecord::VERSION::MAJOR < 4
          # Adds a new column to the named table.
          # See TableDefinition#column for details of the options you can use.
          def add_column(table_name, column_name, type, options = {})
            sql = "ALTER TABLE #{quote_table_name(table_name)} "+
                  "ADD COLUMN #{quote_column_name(column_name)} "+
                  "#{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
            add_column_options!(sql, options)
            execute(sql, SCHEMA_LOG_NAME)
          end

          # Removes the column(s) from the table definition.
          def remove_column(table_name, *column_names)
            if column_names.flatten!
              ActiveSupport::Deprecation.warn(
                'Passing array to remove_columns is deprecated, use multiple arguments',
                caller
              )
            end
            columns_for_remove(table_name, *column_names).each do |column_name|
              # column_name already quoted
              execute(
                "ALTER TABLE #{quote_table_name(table_name)} DROP COLUMN #{column_name}",
                 SCHEMA_LOG_NAME
              )
            end
          end
        end

        # Changes the column's definition according to the new options.
        # See TableDefinition#column for details of the options you can use.
        def change_column(table_name, column_name, type, options = {})
          execute(
            "ALTER TABLE #{quote_table_name(table_name)} "+
            "ALTER COLUMN #{quote_column_name(column_name)} "+
            "SET DATA TYPE #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}",
            SCHEMA_LOG_NAME
          )
          change_column_default(table_name, column_name, options[:default]) if options_include_default?(options)
          change_column_null(table_name, column_name, options[:null], options[:default]) if options.key?(:null)
        end

        # Sets a new default value for a column.
        def change_column_default(table_name, column_name, default)
          execute(
            "ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN "+
            "#{quote_column_name(column_name)} SET DEFAULT #{quote(default)}",
            SCHEMA_LOG_NAME
          )
        end

        # Renames a column.
        def rename_column(table_name, column_name, new_column_name)
          unless columns(table_name).detect{ |c| c.name == column_name.to_s }
            raise ActiveRecord::ActiveRecordError, "No such column #{table_name}.#{column_name}"
          end
          execute(
            "ALTER TABLE #{quote_table_name(table_name)} RENAME COLUMN "+
            "#{quote_column_name(column_name)} TO #{quote_column_name(new_column_name)}",
            SCHEMA_LOG_NAME
          )
          if ActiveRecord::VERSION::MAJOR >= 4
            rename_column_indexes(table_name, column_name, new_column_name)
          end
        end

        def remove_index!(table_name, index_name)
          execute(
            "DROP INDEX #{quote_table_name(table_name)}.#{quote_table_name(index_name)}",
            SCHEMA_LOG_NAME
          )
        end

        # Rename an index.
        def rename_index(table_name, old_name, new_name)
          # TODO: Implement when syntax is supported
          super
        end

        # TODO: implement def index_name_exists?() ?

        if ActiveRecord::VERSION::MAJOR >= 4
          # Patch to add support for grouping option
          def add_reference(table_name, ref_name, options = {})
            super
            grouping_option = options.delete(:grouping)
            add_grouping(table_name, ref_name) if grouping_option
          end
        end

        def type_to_sql(type, limit = nil, precision = nil, scale = nil)
          case type
          when :integer
            # NB: Changes here need reflected in FdbSqlColumn.extract_limit()
            case limit
            when nil, 1..4
              type.to_s
            when 5..8
              'bigint'
            else
              raise(ActiveRecordError, "No integer type has byte size #{limit}. Use a decimal with precision 0 instead.")
            end
          when :decimal
            # Maximum supported as of 1.9.2
            precision = 31 if precision.to_i > 31
            super
          when :text
            case limit
            when nil, 0..0xfffffffe
              super
            else
              raise(ActiveRecordError, "Limit #{limit} exceeds max TEXT length")
            end
          else
            super
          end
        end

        if ActiveRecord::VERSION::MAJOR < 4
          # Returns a SELECT DISTINCT clause for a given set of columns
          # and a given ORDER BY clause.
          #
          # Deprecated in 4.0 in favor of new columns_for_distinct API
          def distinct(columns, orders)
            return super if orders.empty?

            # Construct a clean list of column names from the ORDER BY clause, removing
            # any ASC/DESC modifiers
            order_columns = orders.collect { |s| s.gsub(/\s+(ASC|DESC)\s*(NULLS\s+(FIRST|LAST)\s*)?/i, '') }
            order_columns.delete_if { |c| c.blank? }
            order_columns = order_columns.zip((0...order_columns.size).to_a).map { |s,i| "#{s} AS alias_#{i}" }

            "DISTINCT #{columns}, #{order_columns * ', '}"
          end
        else
          # Given a set of columns and an ORDER BY clause, returns the columns for a SELECT DISTINCT.
          #
          # FDB SQL requires order columns appear in the SELECT.
          def columns_for_distinct(columns, orders)
            # Lifted from the default Postgres implementation
            order_columns = orders.reject(&:blank?).map{ |s|
                # Convert Arel node to string
                s = s.to_sql unless s.is_a?(String)
                # Remove any ASC/DESC modifiers
                s.gsub(/\s+(ASC|DESC)\s*(NULLS\s+(FIRST|LAST)\s*)?/i, '')
              }.reject(&:blank?).map.with_index { |column, i| "#{column} AS alias_#{i}" }

            [super, *order_columns].join(', ')
          end
        end


        # EXTRA METHODS ============================================
        # Unspecified in base but a) used via responds_to or b) common among other adapters

        # Returns the list of all tables in the schema search path or a specified schema.
        def tables(name = nil, schema = nil, table = nil)
          schema = schema ? "'#{quote_string(schema)}'" : 'CURRENT_SCHEMA'
          select_rows(
            "SELECT table_name "+
            "FROM information_schema.tables "+
            "WHERE table_type = 'TABLE' "+
            "  AND table_schema = #{schema} "+
            (table ? "AND table_name = '#{quote_string(table)}'" : ""),
            SCHEMA_LOG_NAME
          ).map { |row|
            row[0]
          }
        end

        # Change a columns NULL-ability and, optionally, current value if NULL.
        # NB: default is only used if changing to NOT NULL. It *does not* become the column DEFAULT
        def change_column_null(table_name, column_name, null, default = nil)
          unless null || default.nil?
            execute(
              "UPDATE #{quote_table_name(table_name)} "+
              "SET #{quote_column_name(column_name)}=#{quote(default)} "+
              "WHERE ISNULL(#{quote_column_name(column_name)})",
              SCHEMA_LOG_NAME
            )
          end
          execute(
            "ALTER TABLE #{quote_table_name(table_name)} "+
            "ALTER COLUMN #{quote_column_name(column_name)} "+
            "#{null ? '' : 'NOT'} NULL",
            SCHEMA_LOG_NAME
          )
        end

        # Drops the schema specified on the +name+ attribute
        # and creates it again using the provided +options+.
        def recreate_database(name, options = {})
          drop_database(name)
          create_database(name, options)
        end

        # Create a new schema. As of 1.9.2, there are no supported options.
        def create_database(name, options = {})
          execute(
            "CREATE SCHEMA #{quote_table_name(name)}",
            SCHEMA_LOG_NAME
          )
        end

        # Drop the schema.
        def drop_database(name)
          execute(
            "DROP SCHEMA IF EXISTS #{quote_table_name(name)} CASCADE",
            SCHEMA_LOG_NAME
          )
        end

        # Get the default character set for the current database
        # TODO: Not currently accessible (or settable from this adapter)
        def charset
          'UTF8'
        end

        # Get the default collation for the current database
        # TODO: Not currently accessible (or settable from this adapter)
        def collation
          'ucs_binary'
        end

        # Returns a table's PRIMARY KEY column
        def primary_key(table_name)
          pk_and_sequence_for(table_name)[0]
        rescue
          nil
        end

        # Returns a table's PRIMARY KEY column and associated sequence.
        # May return nil if none, [pk_col, nil] if no sequence or [pk_col, seq_name]
        def pk_and_sequence_for(table_name, with_seq_schema = false)
          result = select_rows(
            "SELECT kc.column_name, "+
            (with_seq_schema ? "c.sequence_schema, " : "") +
            "       c.sequence_name "+
            "FROM information_schema.table_constraints tc "+
            "INNER JOIN information_schema.key_column_usage kc "+
            "  ON  tc.table_schema = kc.table_schema "+
            "  AND tc.table_name = kc.table_name "+
            "  AND tc.constraint_name = kc.constraint_name "+
            "LEFT JOIN information_schema.columns c "+
            "  ON  kc.table_schema = c.table_schema "+
            "  AND kc.table_name = c.table_name "+
            "  AND kc.column_name = c.column_name "+
            "WHERE tc.table_schema = CURRENT_SCHEMA "+
            "  AND tc.table_name = '#{table_name}' "+
            "  AND tc.constraint_type = 'PRIMARY KEY'",
            SCHEMA_LOG_NAME
          )
          (result.length == 1) ? result[0] : nil
        rescue
          nil
        end

        # Resets the sequence of a table's primary key to the maximum value.
        def reset_pk_sequence!(table_name, primary_key=nil, sequence_name=nil)
          primary_key, seq_schema, sequence_name = pk_and_sequence_for(table_name, true)
          if primary_key && !sequence_name
            @logger.warn "#{table_name} has primary key #{primary_key} with no sequence" if @logger
          end

          if primary_key && sequence_name
            seq_from_where = "FROM information_schema.sequences "+
                             "WHERE sequence_schema='#{quote_string(seq_schema)}' "+
                             "AND sequence_name='#{quote_string(sequence_name)}'"
            result = select_rows(
              "SELECT COALESCE(MAX(#{quote_column_name(primary_key)} + (SELECT increment #{seq_from_where})), "+
              "       (SELECT minimum_value #{seq_from_where})) "+
              "FROM #{quote_table_name(table_name)}",
              SCHEMA_LOG_NAME
            )

            if result.length == 1
              if @sql_layer_version < 10904
                execute(
                  "COMMIT; "+
                  "CALL sys.alter_seq_restart('#{quote_string(seq_schema)}', '#{quote_string(sequence_name)}', #{result[0][0]}); "+
                  "BEGIN;",
                  SCHEMA_LOG_NAME
                )
              else
                execute(
                  "SELECT sys.alter_seq_restart('#{quote_string(seq_schema)}', '#{quote_string(sequence_name)}', #{result[0][0]})",
                  SCHEMA_LOG_NAME
                )
              end
            else
              @logger.warn "Unable to determin max value for #{table_name}.#{primary_key}" if @logger
            end
          end
        end


        # FDB SPECIFIC METHODS =======================================

        # Migration helpers ==========================================

        # Add +table_name+ as a child of +ref_name+
        def add_grouping(table_name, ref_name)
          execute(
            "ALTER TABLE #{quote_table_name(table_name)} ADD "+
            FdbSqlHelpers.grouping_sql_clause(self, ref_name),
            SCHEMA_LOG_NAME
          )
        end

        # Remove grouping from +table_name+
        def remove_grouping(table_name)
          execute(
            "ALTER TABLE #{quote_table_name(table_name)} "+
            "DROP GROUPING FOREIGN KEY",
            SCHEMA_LOG_NAME
          )
        end

        if ActiveRecord::VERSION::MAJOR >= 4
          # Added as private in 4.0.0, moved to public in 4.0.4
          def update_table_definition(table_name, base)
            Table.new(table_name, base)
          end
        end


        private

          SCHEMA_LOG_NAME = 'FDB_SCHEMA'

          NATIVE_DATABASE_TYPES = {
            :primary_key  => { :name => "serial primary key" },
            :string       => { :name => "varchar", :limit => 255 },
            :text         => { :name => "clob" },
            :integer      => { :name => "integer" },
            :float        => { :name => "float" },
            :decimal      => { :name => "decimal" },
            :datetime     => { :name => "datetime" },
            :timestamp    => { :name => "timestamp" },
            :time         => { :name => "time" },
            :date         => { :name => "date" },
            :binary       => { :name => "blob" },
            :boolean      => { :name => "boolean" }
          }


          if ActiveRecord::VERSION::MAJOR < 4
            def table_definition
              FdbSqlTableDefinition.new self
            end
          else
            # as added in 4.1
            def create_table_definition(name, temporary, options, as = nil)
              FdbSqlTableDefinition.new native_database_types, name, temporary, options, as
            end
          end

      end

    end

  end

end


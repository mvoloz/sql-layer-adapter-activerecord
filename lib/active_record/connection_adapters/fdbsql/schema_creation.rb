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
      
      class FdbSqlSchemaCreation < SchemaCreation
        private

          def visit_AddColumn(o)
            sql_type = type_to_sql(o.type.to_sym, o.limit, o.precision, o.scale)
            sql = "ADD COLUMN #{quote_column_name(o.name)} #{sql_type}"
            add_column_options!(sql, column_options(o))
          end

          # Exactly like super.visit_TableDefinition but also includes grouping
          def visit_FdbSqlTableDefinition(o)
            create_sql = "CREATE#{' TEMPORARY' if o.temporary} TABLE "
            create_sql << "#{quote_table_name(o.name)}"
            if o.as
              create_sql << " AS ( #{@conn.to_sql(o.as)} ) WITH DATA"
            else
              create_sql << "("
              create_sql << o.columns.map { |c| accept c }.join(', ')
              if !o.groupings.empty?
                create_sql << ', '
                create_sql << o.groupings.map { |g| accept g }.join(', ')
              end
              create_sql << ") #{o.options}"
            end
            create_sql
          end

          def visit_FdbSqlGroupingDefinition(o)
            FdbSqlHelpers.grouping_sql_clause(@conn, o.ref_name)
          end
      end

    end

  end

end


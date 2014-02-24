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
            create_sql << "#{quote_table_name(o.name)} ("
            create_sql << o.columns.map { |c| accept c }.join(', ')
            if !o.groupings.empty?
              create_sql << ', '
              create_sql << o.groupings.map { |g| accept g }.join(', ')
            end
            create_sql << ") #{o.options}"
            create_sql
          end

          def visit_FdbSqlGroupingDefinition(o)
            FdbSqlHelpers.grouping_sql_clause(@conn, o.ref_name)
          end
      end

    end

  end

end


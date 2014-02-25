module ActiveRecord

  module ConnectionAdapters

    class FdbSqlHelpers

      def self.grouping_sql_clause(quoter, ref_name)
        # Assumes reference/belongs_to already exists
        table_column = "#{ref_name}_id"
        "GROUPING FOREIGN KEY (#{quoter.quote_column_name(table_column)}) "+
        "REFERENCES #{quoter.quote_table_name(ref_name)}"
      end

    end

  end

end


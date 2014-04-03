module ActiveRecord

  module ConnectionAdapters

    class FdbSqlHelpers

      def self.grouping_sql_clause(quoter, ref_name)
        plural = ActiveRecord::Base.pluralize_table_names ? ref_name.to_s.pluralize : ref_name
        # Assumes reference/belongs_to already exists
        table_column = "#{ref_name}_id"
        "GROUPING FOREIGN KEY (#{quoter.quote_column_name(table_column)}) "+
        "REFERENCES #{quoter.quote_table_name(plural)}"
      end

    end

  end

end


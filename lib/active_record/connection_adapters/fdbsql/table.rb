module ActiveRecord

  module ConnectionAdapters

    # Add new methods for use in change_table migrations as
    # the Table type is not customizable until 4.0

    class Table

      def add_grouping(ref_name)
        @base.add_grouping(@table_name, ref_name)
      end

      def remove_grouping()
        @base.remove_grouping(@table_name)
      end

    end

  end

end


module ActiveRecord

  module ConnectionAdapters

    # Add new methods for use in change_table migrations as
    # the Table type is not customizable until 4.0

    class Table

      # Defers to add_reference in 4, which is already patched
      if ActiveRecord::VERSION::MAJOR < 4
        orig_references = instance_method(:references)
        define_method(:references) do |*args|
          orig_references.bind(self).(*args)
          options = args.extract_options!
          grouping = options.delete(:grouping)
          args.each do |col|
            @base.add_grouping(@table_name, col) if grouping
          end
        end
      end

      def add_grouping(ref_name)
        @base.add_grouping(@table_name, ref_name)
      end

      def remove_grouping()
        @base.remove_grouping(@table_name)
      end

    end

  end

end


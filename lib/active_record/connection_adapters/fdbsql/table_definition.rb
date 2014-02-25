module ActiveRecord

  module ConnectionAdapters

    if ActiveRecord::VERSION::MAJOR < 4

      class FdbSqlGroupingDefinition < Struct.new(:base, :ref_name)
        def to_sql
          FdbSqlHelpers.grouping_sql_clause(base, ref_name)
        end
      end

      class FdbSqlTableDefinition < TableDefinition
        # Array of GroupingDefinitions
        attr_accessor :groupings

        def initialize(base)
          super
          @groupings = []
        end

        # Patch to add support for grouping option
        def references(*args)
          super
          options = args.extract_options!
          args.each do |col|
            @groupings << FdbSqlGroupingDefinition.new(@base, col) if options.delete(:grouping)
          end
        end

        def to_sql
          create_sql = super
          create_sql << ", #{@groupings.map { |g| g.to_sql } * ', '}" unless @groupings.empty?
          create_sql
        end
      end

    else

      class FdbSqlGroupingDefinition < Struct.new(:ref_name)
      end

      class FdbSqlTableDefinition < TableDefinition
        # Array of GroupingDefinitions
        attr_accessor :groupings

        def initialize(types, name, temporary, options)
          super
          @groupings = []
        end

        # Patch to add support for grouping option
        def references(*args)
          super
          options = args.extract_options!
          args.each do |col|
            @groupings << FdbSqlGroupingDefinition.new(col) if options.delete(:grouping)
          end
        end
      end

    end

  end

end


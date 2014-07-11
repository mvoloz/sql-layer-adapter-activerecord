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

        # NB: as added in 4.1.0
        def initialize(types, name, temporary, options, as = nil)
          if ActiveRecord::VERSION::MAJOR > 4 || ActiveRecord::VERSION::MINOR >= 1
            super
          else
            super(types, name, temporary, options)
          end
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


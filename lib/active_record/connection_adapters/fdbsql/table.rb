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


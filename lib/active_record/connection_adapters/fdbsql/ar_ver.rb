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
      
      module ArVer

        LT_4 = (ActiveRecord::VERSION::MAJOR < 4)
        GT_4= (ActiveRecord::VERSION::MAJOR > 4)
        GTEQ_4 = (ActiveRecord::VERSION::MAJOR >= 4)
        GTEQ_4_0_4 = (GTEQ_4 and (GT_4 or ActiveRecord::VERSION::MINOR >= 1 or ActiveRecord::VERSION::TINY >= 4))
        GTEQ_4_1 = (GTEQ_4 and (GT_4 or ActiveRecord::VERSION::MINOR >= 1))
        
      end

    end

  end

end

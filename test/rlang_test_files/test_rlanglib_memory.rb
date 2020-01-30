require 'rlang/lib/memory'

class Test
  export
  def self.test_rlanglib_memory(more_pages)
    if (more_pages == 0)
      ret = Memory.size
    else
      ret = Memory.grow(more_pages)
    end
    return ret
  end
end
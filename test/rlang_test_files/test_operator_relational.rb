require 'rlang_core'

class Test

  export
  def self.test_operator_relational
    local uv1: :UI32, uv2: :UI32
    local v1: :I32, v2: :I32

    # With signed integers
    v1=1;v2=2
    return 1 if !(v1 < v2)
    return 2 if v1 > v2
    return 3 if !(v1 <= v2)
    return 4 if v1 >= v2

    v1=-1_500_000; v2=-1_200_000
    return 5 if !(v1 < v2)
    return 6 if v1 > v2
    return 7 if !(v1 <= v2)
    return 8 if v1 >= v2

    v1=-1_500_000; v2=10
    return 9 if !(v1 < v2)
    return 10 if v1 > v2
    return 11 if !(v1 <= v2)
    return 12 if v1 >= v2
    
    # With unsigned integers
    uv1=1;uv2=2
    return 13 if !(uv1 < uv2)
    return 14 if uv1 > uv2
    return 15 if !(uv1 <= uv2)
    return 16 if uv1 >= uv2

    uv1=4294967294;uv2=4294967295 # 2**32-2, 2**32-1
    return 17 if !(uv1 < uv2)
    return 18 if uv1 > uv2
    return 19 if !(uv1 <= uv2)
    return 20 if v1 >= v2

    uv1=10; uv2=10
    return 21 if uv1 < uv2
    return 22 if uv1 > uv2
    return 23 if !(uv1 <= uv2)
    return 24 if !(uv1 >= uv2)

    # With unsigned and signed integers
    # v2 will be automatically converted to an
    # unsigned integer
    uv1=10;v2=-1
    return 25 if !(uv1 < v2)

    # All good
    return 0
  end
end
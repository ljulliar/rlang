class Test
  def self.fib(n)
    if n <= 1
      f = n
    else
      f = self.fib(n-1) + self.fib(n-2)
    end
    return f
  end

  export
  def self.test_call_method_recursive(n)
    self.fib(n)
  end
end
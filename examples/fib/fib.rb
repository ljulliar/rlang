class Math
  export
  def self.fib(n)
    if n <= 1
      f = n
    else
      f = self.fib(n-1) + self.fib(n-2)
    end
    return f
  end
end

def self.main
  Math.fib(12)
end

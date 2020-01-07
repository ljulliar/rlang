# The Rlang language

Rlang is a subset of the Ruby language that is meant to provide a certain level of abstration and expresiveness while keeping its translation to WebAssembly relatively straightforward. 

Ruby programmers will feel at home with Rlang and non Ruby programmers might still find it useful to generate efficient WebAssembly code from a language that is much easier to use.

Still, to make this Ruby to WebAssembly translation possible we had to make some compromise. The goal of this document is to explain what those limitations are compared to standard Ruby.

## The Rlang object model

To be blunt, there is no such thing as a *Rlang object model* for the reason that Rlang does **not** support object instantiation. Why is that? Well, object instantiation in Ruby means, among other things, that we are capable of allocating memory dynamically. Something WebAssembly is not capable of doing out of the box. Supporting this would more or less mean that Rlang becomes a Ruby virtual machine and this is absolutely not the intent. What the intent is with Rlang is to provide you with a language that can assist you in developing such a Virtual Machine for instance ;-)

## What Rlang does

The above limitation on the object model might look like a serious handicap to you but you'll be surprised at how much you can achieve with Rlang in no time.

Rlang provides:
* Classes and class variables
* Method definition and method calls
* Integers (both long and double or i32 and i64 to use the WebAssembly terminology) 
* Constants
* Global variables
* Control constructs (if, while, until, break, next,...)
* Arithmetic, relational and logical operators
* WebAssembly source code (WAT) inlining
* Requiring other Rlang or WAT files
* A Rlang library (written in Rlang of course) that you can use in your own code

Here is a sample of Rlang code to whet your appetite:

```ruby
class Math
  def self.fib(n)
    if n <= 1
      f = n
    else
      f = self.fib(n-1) + self.fib(n-2)
    end
    return f
  end
end
```

calling that method later in your code is as simple as invoking `Math.fib(20)`

## Classes
Classes are core constructs of Rlang. A Class plays the role of a namespace.

Within a class you define methods and class variables. Actually any method must be defined within a class. In other words you can not syntactically define a method at the top level as you could do in Ruby (not a very good practice anyway). Also there is no inheritance mechanism in Rlang.

Here is an example of a class definition and the initialization and use of a class variable

```ruby
class MyClass
  @@cvar = 100

  def self.take_one
    self.refill if @@cvar == 0
    @@cvar -= 1
  end

  def self.refill
    @@cvar = 100
  end
end
```

This short piece of code shows you several interesting points:
1. A class variable can be statically initialized at the class level. Concretely this means that at compile time the memory location corresponding to the `@@cvar` class variable initially receives the value 100.
1. Since there is no objects in Rlang, all methods must be defined as class methods, hence the use of `self.take_one` and `self.refill` in method definitions
1. In `MyClass::take_one` you see how to call a method from the same class. You also see that you can use if as a modifier too. You can also combine operation and assignment as in Ruby (here the `-=` operator)

## Methods
As there is no such such thing as object instances in Rlang right now, only class methods are supported. You define class method as you would normally do in Ruby by using `def self.method_name` 

### Method arguments
Rlang method definition supports fixed name arguments in any number. So the following are all valid method definitions: `def self.m_no_arg`, `def self.m_two_args(arg1, arg2)`

By default all arguments in Rlang are considered as being type i32 (a 32 bit integer). See the Type section below for more details. If your argument is of a different type you **must** explicitely state it. 
```ruby
def self.m_two_args(arg1, arg2)
  arg :arg2, :I64
  # your code here...
end
```
In the example above arg1 is of type i32 (the default type) and assuming arg2 is of type i64, it must be explicitely declared as such.

### Return result
Unless otherwise stated, a method must always return an integer value of type i32 (the default type in Rlang). If your method doesn't return anything or a value of a different type you have to say so with the `result` directive.

```ruby
def self.m_no_return_value(arg1, arg2)
  arg :arg2, :I64
  result :none
  # your code here
  # ...
  # and return nothing
  return
end
```
Similarly you can use `return :I64` if your method is to return a double integer value.

With a few exceptions (see the Conditional and Iteration Structures sections below), each Rlang statements evaluate to a value. In the absence of a `return some_expression` statement, a method returns the value of the last evaluated statement. In the example above the method `MyClass::take_one` returns the value of `@@cvar` after decreasing it by one and `MyClass::refill` returns 100.

Rlang also gives you the ability to declare the return type of a method like this 
```result class_name, method_name, wasm_type```

This result directive must be used whenever a method is used in your Rlang source code **before** it is actually parsed. See it as a type declaration like stattically typed language. But keep in mind that this only needed if the method returns something different than the default type (i32).

For an example see the [test_def_result_type_declaration.rb](https://github.com/ljulliar/rlang/blob/master/test/rlang_files/test_def_result_type_declaration.rb) test file.

### Local variables
Local variable used in a method body doesn't have to be declared. They are auto-vivified the first time you assign a value to it. In some cases though, you may have to use the `local` directive as in the example below to explicitely state the type of a local variable.

```ruby
def self.m_local_var(arg1)
  local :lvar, :I64
  lvar = 10
  # ....
end
```
In this example, without the `local :lvar, :I64` directive, `lvar` would have been typed as `i32` because the assigned value (here `10`) is itself interpreted as an `i32` value by default. 

### Exporting a method
In WebAssembly, you can make functions visible to the outside world by declaring them in the export section. To achieve a similar result in Rlang, you can use the `export` keyword right before a method definition. 

```ruby
class MyClass

  export
  def self.m_visible(arg1)
    # ...
  end

  def self.m_not_visible
    # ...
  end
end
```

Note that the `export` keyword only applies to the method definition that immediately follows. In the example above `MyClass::m_visible` will be exported by the generated WASM module whereas `MyClass::m_not_visible` will not

WASM exported functions are named after the class name (in lower case) followed by an underscore and the method name. So the exported method in the example above is known to the WASM runtime as the `myclass_m_visible` function.

## Rlang types
The only types currently supported by Rlang are integers either long (`i32`) or double (`i64`). Float may follow in a future version. By default Rlang assumes that any integer literal and variable is of type `i32`. If you need it to be of a different type you must state it explicitely in the method body (see above).

### Implicit type cast
Only in rare cases will you use the `local` directive in methods as Rlang does its best to infer the type of a variable from its first assigned value. As an example, in the code below, the fact that `arg1` is known to be an `i64` type of argument is enough to auto-magically create lvar as in `i64` local variable too

```ruby
def self.m_local_var(arg1)
  arg :arg1, :I64
  lvar = arg1 * 100
  # ....
end
```

Conversely in the method below the first statement `lvar = 10` auto-vivifies `lvar` as a variable of type `i32` (the default Rlang type. On the next line, Rlang will determine that `arg1 * 100` gives an `i64` result (because `arg1` is declared as being of type `i64` and, consequently automatically type casting the result of the expression to `i32` because this is the type of `lvar`.Such a type cast may of course result in the value being truncated and the Rlang compiler will emit a warning accordingly.

```ruby
def self.m_local_var(arg1)
  arg :arg1, :I64
  lvar = 10 # lvar is auto-vivified as i32
  lvar = arg1 * 100
  # ....
end
```

### Explicit type cast
Finally if Rlang is not capable of guessing the proper type of an expression and declaring the variable type explicitely is not possible (e.g. for global or class variables), you can use the specific type cast methods `to_i32` or `to_i64`

Going back to the first example in class `MyClass`, what if you wanted to create the class variable @@cvar1 as an i64 variable ? This is where the type cast methods come handy. As in example below:

```ruby
class MyClass
  @@cvar = 100.to_i64
  # your code here
  #...
end
```

## Constants
Rlang supports constants too  and you can invoke constants from different classes as you would in Ruby. In the example below the `TestB::m_constants` returns 1001 as a result

```ruby
class TestA
  CONST = 1000
  # your code here
end

class TestB
  CONST = 1

  export
  def self.m_constants
    CONST + TestA::CONST
  end
end
```

## Global variables
Rlang provides global variable as well. Whereas a constant can only be defined within the scope of a class definition, a global variable can be defined anywhere. When defined at the top level one can only assign a literal value like 100 (or 100.to_i64) in the example. Assigning an expression can only be done within the scope of a method.

```ruby
$MYGLOBAL = 100

class TestB
  CONST = 1

  export
  def self.m_constants
    CONST + $MYGLOBAL
  end
end
```

## Conditional statements
Rlang supports the following Ruby conditional statements:
* if/unless-end
* if/unless-else-end
* if-elsif-....- elsif-end
* as well as if and unless use as modifiers

**IMPORTANT REMARK** As opposed to Ruby, Rlang conditional statements never evaluates to a value. This is not much of a problem as even in regular Ruby code this feature is rarely used. However you might want to pay attention to some corner cases like the fibonacci method shown at the beginning of this document. In regular Ruby you would use the following code:

```ruby
def self.fib(n)
  if n <= 1
    n
  else
    fib(n-1) + fib(n-2)
  end
end
```

but as the if and else clauses doesn't return any value in Rlang you'll need to collect the value in a local variable and return that value with an explicit return statement as in the first example

## Iteration statements
Rlang supports the following Ruby iteration statements:
* while do-end
* until do-end

`break` and `next` statements are also supported

**IMPORTANT REMARK** As opposed to Ruby, Rlang iteration statements never evaluates to a value.

## Operators

Here is the list of operators supported by Rlang:

* Arithmetic operators: +, -, *, /, %, &, |, ^, >>, <<
* Relational operators: ==, !=, <, >, <=, >=
* Logical operators: &&, ||, !

## Requiring files
`require` and `require_relative` are supported by Rlang. It means that, like in plain Ruby, you can split your Rlang classes in distinct files, require them in a master file and compile this single master file.

`require` looks for file in the Rlang load path that you can define by using the `-I` command line option of the rlang compiler (See the [Rlang Compiler Documentation](https://github.com/ljulliar/rlang/blob/master/docs/RlangCompiler.md). However for your Rlang projects, we strongly suggest using `require_relative` rather than `require` as all your Rlang files most likely form a single entity that you'll end up compiling into a single WebAssembly module.

If no extension is specified for the required file, Rlang will start looking for a matching `.wat` file first (which means you can include hand written WAT files in your Rlang projects) and second for a matching `.rb` file.

## Code inlining
There are two ways to use WAT code directly in your Rlang projects:
* The first one is to require a `.wat` file (see previous section)
* The second is to use the `inline` directive directly in your code.

Here is an example:
```ruby
class MyOtherClass
  def self.x10_square(arg1)
    arg1 *= 10
    inline wat: '(i32.mul 
                   (local.get $arg1)
                   (local.get $arg1))',
           ruby: 'arg1 ** 2'
  end
end
```
What this code sample does is to multiply the method argument by 10 (in Ruby) and then inline some WAT code that squares this argument. The reason for the `ruby:` keyword argument is to give the equivalent Ruby code that will be used when you run your Rlang code in the Rlang simulator (still in development).

A third keyword argument `wtype:` also allows to specifiy the WebAssembly type produced by the fragment of inlined WAT code. By default it is assumed to produce an `i32`. If not you can either specify `wtype: :I64` or `wtype: :none`

## The Rlang library
Rlang comes with a library that provides a number of pre-defined classes and methods (written in Rlang of course) that you can use by adding the following statement in your Rlang files

```ruby
require 'rlang/lib'
```

For now, the Rlang library is very modest and only contains WebAssembly memory management functions like Memory::size and Memory::grow

That's it! Enjoy Rlang and, as always, feedback and contributions are welcome.
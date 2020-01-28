# The Rlang language

Rlang is a subset of the Ruby language that is meant to provide a certain level of abstration and expressiveness while keeping its translation to WebAssembly straightforward. 

Ruby programmers will feel at home with Rlang and non Ruby programmers will find it useful to generate efficient WebAssembly code from a language that is much easier to use.

Still, to make this Ruby to WebAssembly compilation possible a number of trade-offs had to be made. The goal of this document is to explain the features of Rlang are how it differs from plain Ruby.

## The Rlang object model

In Rlang you can define classes and those classes can be instantiated but *only* statically not dynamically. Supporting dynamic object allocation would more or less mean that Rlang becomes a Ruby virtual machine and this is not the intent. What the intent is with Rlang is to provide you with a language that can assist you in developing such a Virtual Machine for instance ;-)

One of the consequence of this for instance is that you can statically instantiate a new object in the body of a class not in a method. In other words objects can be instantiated at compile time not at runtime (note: this may change in a future version)

## What Rlang does

Rlang provides:
* Classes, class attributes and class variables
* Object instantiation (only at compile time)
* Method definition and method calls
* Integers and booleans 
* Constants
* Global variables
* Control constructs (if, while, until, break, next,...)
* Arithmetic, relational and logical operators
* WebAssembly source code (WAT) inlining
* Requiring other Rlang or WAT files
* A Rlang library (written in Rlang of course) that you can reuse in your own WebAssembly module

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
Classes are core constructs of Rlang and are very similar to Ruby classes.

Within a class you define methods and class variables. Actually all methods must be defined within a class. In other words you can not define a method at the top level of your Rlang code (not a very good practice anyway, even in plain Ruby). Also there is no inheritance mechanism in Rlang in the current version.

Here is an example of a class definition and the initialization and use of a class variable written in Rlang:

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

This short piece of code shows several interesting points:
1. A class variable can be statically initialized at the class level. Concretely this means that at compile time the memory location corresponding to the `@@cvar` class variable initially receives the value 100.
1. Methods in this example are class methods, hence the use of `self.take_one` and `self.refill` in method definitions but instance methods are also supported (more on this later)
1. In `MyClass::take_one` you can see that Rlang also supports convenient syntactic sugar like `if` as a modifier or combined operation and assignment as in Ruby (here the `-=` operator)

### Class attributes
Since objects cannot be instantiated at runtime in Rlang, there is no such thing as instance variable. Rlang uses a special directive `wattr` to do 4 things at once: 
1. Define the attributes of a class (see that as its instance variables somehow)
2. Define the type of the attributes (remember, Rlang is a compiler...)
2. Define the corresponding accessors both getter and setter (like `attr_accessor` does in Ruby)
3. Compute the memory footprint needed when objects of this class are instantiated.

That's a lot with a single statement and it makes your code easy to read. Here is an example
```ruby
class Square
  wattr :side

  def area
    self.side * self.side
  end
end
```
Later in your code you could use this class in your code as follows

```ruby
class Test
  @@square = Square.new

  def self.my_method
    @@square.side = 10
    @@square.area
  end
end
```

The code is pretty straightforward: a new square instance is created, its side is set to 10 and as you would expect the call to the Square#area method would return 100.

### Class attribute type
In the example above the `side` attribute is implicitely using the `:I32` (long integer) WebAssembly type. It's the default Rlang type. Assuming you want to manage big squares, you'd have to use `:I64` (double integer) like this for the `side` attribute and also instruct Rlang that the return value of area is also `:I64` (more on this later).

```ruby
class Square
  wattr :side
  wattr_type side: :I64

  def area
    result :I64
    self.side * self.side
  end
end
```

## Object instantiation
In the current version of Rlang objects can only be instantiated at compile time not at runtime. As a result of this, all object instantiation must happen in the body of a class not in the body of a method. You have already seen an example of such an object instantiation in the previous example with `Square.new` being instantiated and stored in the class variable `@@cvar`.

Similarly you can also instantiate and store an object in a global variable.

## Methods
Methods in Rlang are defined as you would normally do in Ruby by using. They can be either class or instance methods.

### Method arguments
Rlang method definition supports fixed name arguments in any number. The  *args and **args notation are not supported.

By default all arguments in Rlang are considered as being type `:I32` (a 32 bit integer). See the Type section below for more details. If your argument is of a different type you **must** explicitely state it. 
```ruby
def self.m_two_args(arg1, arg2, arg3)
  arg arg1: :Square, arg2: :I64
  # your code here...
end
```
In the example above arg1 is of type Square (the class we defined earlier), arg2 is of type `:I64` and arg3 not being mention in the arg list of of default type (`:I32`)

### Return result
Unless otherwise stated, a method must return a value of type `:I32` (the default type in Rlang). If your method returns nothing or a value of a different type you have to say so with the `result` directive.

```ruby
def self.m_no_return_value(arg1, arg2)
  result :none
  # your code here
  # ...
  # and return nothing
  return
end
```
Similarly you can use `return :I64` if your method is to return a double integer value or `return :Square` if you method returns an object.

With a few exceptions (see the Conditional and Iteration Structures sections below), each Rlang statements evaluate to a value. In the absence of an explicit `return some_expression` statement, a method returns the value of the last evaluated statement. In the example above the method `MyClass::take_one` returns the value of `@@cvar` after decreasing it by one and `MyClass::refill` returns 100.

Rlang also gives you the ability to declare the return type of a method like this 
```ruby
result :class_name, :method_name, :wasm_type
```

This result directive must be used to instruct the compiler about the return type of a method if it has not seen it yet (e.g. the method definition is coming later in your source code). But keep in mind that this is only needed if the method returns something different than the default type (`:I32`).

If `:method_name` symbol starts with a `#` it refers to an instance method. Without it it refers to a class method.

For an example see the [test_def_result_type_declaration.rb](https://github.com/ljulliar/rlang/blob/master/test/rlang_test_files/test_def_result_type_declaration.rb), a Rlang file that is part of the Rlang test suite.

### Local variables
Local variable used in a method body doesn't have to be declared. They are auto-vivified the first time you assign a value to it. In some cases though, you may have to use the `local` directive as in the example below to explicitely state the type of a local variable.

```ruby
def self.m_local_var(arg1)
  local lvar: :I64, mysquare: :Square
  lvar = 10
  mysquare = @@square
  # ....
end
```
In this example, the `local` directive instructs the compiler that `lvar` is of type `:I64` and the local variable mysquare is of type `Square`.

### Exporting a method
In WebAssembly, you can make functions visible to the outside world by declaring them in the export section. To achieve a similar result in Rlang, you can use the `export` keyword right before a method definition. 

```ruby
class MyClass

  export
  def self.visible(arg1)
    # ...
  end

  def self.not_visible
    # ...
  end
end
```

Note that the `export` keyword only applies to the method definition that immediately follows. In the example above `MyClass::m_visible` will be exported by the generated WASM module whereas `MyClass::m_not_visible` will not

WASM exported functions are named after the class name (in lower case) followed by an underscore and the method name. So the exported method in the example above is known to the WASM runtime as the `myclass_c_visible` function (where the `_c_` means it's a class function and `_i_` an instance method)

## Rlang types
The types currently supported by Rlang are integers either long (`:I32`) or double (`:I64`) or a class type. Float types (:F32, :F64) may follow in a future version. By default Rlang assumes that any integer literal, variable, argument,... is of type `:I32`. If you need it to be of a different type you must state it explicitely in the method body (see above).

### Implicit type cast
Only in rare cases will you use the `local` directive in methods as Rlang does its best to infer the type of a variable from its first assigned value. As an example, in the code below, the fact that `arg1` is known to be an `:I64` type of argument is enough to auto-magically create lvar as in `:I64` local variable too.

```ruby
def self.m_local_var(arg1)
  arg :arg1, :I64
  lvar = arg1 * 100
  # ....
end
```

Conversely in the method below the first statement `lvar = 10` auto-vivifies `lvar` as a variable of type `:I32` (the default Rlang type). On the next line, Rlang evaluates `arg1 * 100` as an `:I64` result because `arg1` is declared as being of type `:I64`. Similarly as the type of `lvar` local variable was auto-vivified as `:I32`, the result of the expression `arg1 * 100` will be type cast from `:I64` to `:I32`. Note that Such a type cast may of course result in the value being truncated and the Rlang compiler will emit a warning accordingly.

```ruby
def self.m_local_var(arg1)
  arg :arg1, :I64
  lvar = 10 # lvar is auto-vivified as :I32
  lvar = arg1 * 100
  # ....
end
```

### Explicit type cast
If Rlang is not capable of guessing the proper type of an expression or variable, you can explicitely cast it to any known type. Look at this example:

```ruby
class MyClass
  @@cvar = 100.cast_to(:I64)
  @@square = 123876.cast_to(:Square)
  # your code here
  #...
end
```

The first line will auto-vivify the `@@cvar` class variable as type `:I64`. 

The second example turns the value `123876` into a pointer to a `Square` object. In the absence of dynamic object instantiation this allows you to create your own object at runtime by allocating WebAssembly memory and pointing to it as if it was an object of you choice (see Rlang library below for memory management) 

For `:I32` and `:I64` type cast you can also use the following shortcuts `100.to_I64` or `100.to_I32`

Note that type cast can be used anywhere in the code whether in class body or method definition.

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

## Booleans
Rlang the booleans `true` and `false`. You can use them in conditional statements like in the example below. As expected the `x` local variable equals would equal 10 when breaking from the loop

```ruby
x = 0
while true
  x += 1
  break if x == 10 
end
```
As opposed to Ruby though, `true` and `false`are not instances of TrueClass and FalseClass but are internally represented respectively as `1` and `0`. More generally in Rlang (pretty much like in C) any non zero integer value will be considered true. However we strongly advise against mixing boolean condition and integer arithmetics. Like in C this can lead to **very** nasty bugs that will be hard to debunk.

## Global variables
Rlang provides global variable as well. Whereas a constant can only be defined within the scope of a class definition, a global variable can be defined anywhere. When defined at the top level one can only assign a literal value like 100 (or 100.to_I64). Assigning an expression can only be done within the scope of a method.

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

**IMPORTANT REMARK** As opposed to Ruby, Rlang conditional statements never evaluates to a value. This is not much of a problem as even in regular Ruby code this feature is rarely used. However you might want to pay attention to some corner cases like in the fibonacci method shown at the beginning of this document. In regular Ruby you would use the following code:

```ruby
def self.fib(n)
  if n <= 1
    n
  else
    fib(n-1) + fib(n-2)
  end
end
```

but as the if and else clauses doesn't return any value in Rlang you must collect the value in a local variable and return that local variable with an explicit return statement.

## Iteration statements
Rlang supports the following Ruby iteration statements:
* while do-end
* until do-end

`break` and `next` statements are also supported

**IMPORTANT REMARK** As opposed to Ruby, Rlang iteration statements never evaluates to a value.

## Operators

Here is the list of operators supported by Rlang:

* Arithmetic operators: `+`, `-`, `*`, `/`, `%`, `&`, `|`, `^`, `>>`, `<<`
* Relational operators: `==`, `!=`, `<`, `>`, `<=`, `>=`
* Logical operators: `&&`, `||`, `!`

### Arithmetics operators
Arithmetics operators does the same as in plain Ruby. They apply to `:I32` and `:I64` types. They will apply equally to `:F32` and `:F64` when supported by Rlang

### Relational operators
Relational operators does the same as in plain Ruby. They apply to `:I32` and `:I64` types. They will apply equally to `:F32` and `:F64` when supported by Rlang

All relational operators evaluate to a boolean value (see above) either `true` (value 1) or `false` (value 0)

### Logical operators
Logical (aka Boolean) operators `&&` (logical AND), `||` (logical OR) and `!` (logical NOT) acts as in plain Ruby.

It's a Rlang best practice to apply logical operators to boolean values only (e.g. `true`, `false` or boolean values resulting from comparisons). However in Rlang all non zero value is equivalent to true so, like in C, you can mix and match both booleans and integer values although it is not recommended as it typically leads to very nasty bugs that are hard to spot.

### Pointer Arithmetics
With the ability to define classes with attributes and instantiate objects from those classes, comes the notion of pointer arithmetics. When a new object is instantiated in Ruby, it is assigned a unique object ID. Similaly in Rlang the statement `@@cvar = Square.new`, will instatiate a new object, allocate the space needed in the WebAssembly memory, return the address of this memory space and, in this particular case, store the address i a class variable. In other words, `@@cvar` is a pointer to the new object.

With this we can start using pointer arithmetics like you would do in C. Supported operators are `+`, `-` as well as all relational operators `==`, `!=`, `<`, `>`, `<=`, `>=`. As an example the statement `@@cvar += 1` would result in @@cvar pointing to a memory address increased by the size of the Square object (here 8 bytes as Square has one `I64` attribute)

You can see examples of pointer arithmetics are work in the memory allocator class (Malloc) provide in the Rlang library.

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

A third keyword argument `wtype:` also allows to specifiy the WebAssembly type produced by the fragment of inlined WAT code. By default it is assumed to produce an `:I32`. If not you can either specify `wtype: :I64` or `wtype: :none`

## The Rlang library
Rlang comes with a library that provides a number of pre-defined classes and methods (written in Rlang of course) that you can use by adding the following statement in your Rlang files

```ruby
require 'rlang/lib'
```

For now, the Rlang library is very modest and only contains basic WebAssembly memory management functions like `Memory::size` and `Memory::grow` to mirror the WebAssembly functions of the same name.

That's it! Enjoy Rlang and, as always, feedback and contributions are welcome.
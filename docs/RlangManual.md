# The Rlang language

Rlang is a subset of the Ruby language that is meant to provide a good level of abstraction and expressiveness while keeping its compilation to WebAssembly straightforward. 

Ruby programmers will feel at home with Rlang and non Ruby programmers will find it useful to generate efficient WebAssembly code from a language that is much easier to use.

Still, to make this Ruby to WebAssembly compilation possible a number of trade-offs had to be made. The goal of this document is to explain the features of Rlang are how it differs from plain Ruby.

## What Rlang does

Rlang provides:
* Classes, class attributes and class variables
* Modules
* Object instantiation, attribute accessors and instance variables
* Method definition and method calls
* Integers and booleans 
* Constants
* Global variables
* Static Data
* Control constructs (if, while, until, break, next,...)
* Arithmetic, relational and logical operators
* WebAssembly source code (WAT) inlining
* Requiring other Rlang or WAT files
* Importing and exporting WASM functions
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

Here is an example of a class definition and the initialization and use of a class variable written in Rlang (note: this example uses only class methods on purpose. Instance methods are covered later in this document):

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
1. A class variable can be statically initialized at the class level. Concretely this means that at compile time the memory location corresponding to the `@@cvar` class variable is statically initialized at 100.
1. Methods in this example are class methods, hence the use of `self.take_one` and `self.refill` in method definitions but instance methods are also supported (more on this later)
1. In `MyClass::take_one` you can see that Rlang also supports convenient syntactic sugar like `if` as a modifier or combined operation and assignment as in Ruby (here the `-=` operator)

### Class scope and inheritance
Rlang supports the definition of classes in class at any depth and class naming follows the exact same convention as in Ruby. In the example below the `B` class can be referred to as `A::B`. 

```ruby
class A
  class B
  end
end

def main
  new_object = A::B.new
end
```
A Class in RLang can also inherit from another class as in Ruby. Whan a superclass is not specified, a newly defined class automatically inherits from the Object class.

If you need to use a class name in your code before the class is actually processed by the compiler you can use the following empty class notation to declare that the corresponding constant is actually a class. You can later reopen the class definition and define methods.

```ruby
class String; end
```


### Class attributes and instance variables
Rlang support both the use of class attributes and instance variables. Class attribute declaration is happening through the `attr_accessor`, `attr_reader` or `attr_writer` directives as in plain Ruby. It actually defines a couple of things for you:

Here is an example showing the definition of a single attribute both in read and write mode.
```ruby
class Square
  attr_accessor :side

  def area
    @side * @side
  end
end
```
Later in your code you could 

```ruby
class Test

  def self.my_method
    s = Square.new
    s.side = 10
    area = square.area
    perimeter = s.side * 4
  end
end
```

The code is pretty straightforward: a new square instance is created, its side attribute is set to 10. As you would expect, the call to the Square#area method returns 100 and the perimeter is 40.

### Class attribute type
In the example above the `side` attribute is implicitely using the `:I32` (signed 32-bit integer) WebAssembly type. It's the default Rlang type. Assuming you want to manage big squares, you'd have to use `:I64` (double integer) like this for the `side` attribute and also instruct Rlang that the return value of area is also `:I64` (more on this later).

```ruby
class Square
  attr_accessor :side
  attr_type side: :I64

  def area
    result :I64
    @side * @side
  end
end
```
## Modules
Modules in Rlang behaves exactly like modules in Ruby. Modules can be included, extended or prepended in other classes and modules. .

## Object instantiation
Starting with version 0.4.0, Rlang is equipped with a dynamic memory allocator (see [Rlang library](#the-rlang-library) section). It is therefore capable of allocating objects in a dynamic way at *runtime*. Prior versions were only capable of allocating objects statically at *compile* time.

### Static objects
A statement like `@@square = Square.new` appearing in the body of a class definition result in a portion of the WebAssembly memory being statically allocated at compile time by Rlang. The `@@square` class variable points to that particular memory location. Similarly you can also statically instantiate and store an object in a global variable or in a constant like this:

```ruby
class Test
  @@square = Square.new
  SQUARE = Square.new
  $SQUARE = Square.new

  # Your methods below...
  # ...
end
```
The address in memory of both class variables and constants can be accessed by using the `addr` method as in `SQUARE.addr` for instance.

**IMPORTANT NOTE**: in the current version of Rlang the new method call used to allocate static objects doesn't do any initialization. That's why the new method in this context (class body or top level) doesn't accept any parameter.

### Dynamic objects
At any point in the body of method you can dynamically instantiate a new object. Here is an exemple:

```ruby
class Cube

  def initialize(x, y, z)
   @x = x; @y = y; @z = z
  end

  def volume
    @x * @y * @z
  end
end
```
In this example the `Cube` method uses 3 instance variables `@x`, `@y`, `@z`.

Whenever you define a class, Rlang automatically generate the MyClass._size_ class method. Calling this method will tell you how many bytes MyClass objects uses in memory. As an example, a call to `Cube._size_` would return 12 as the 3 instance variables of Cube are of type `I32` using 4 bytes each in memory.

### Garbage collection
In its current version, Rlang doesn't come with a garbage collector. All dynamically allocated objects must eventually be freed explicitely using the `Object.free` method in your code when objects are no longer needed.

Here is an example building on the Cube class that we just defined:
```ruby
class Main
  def self.run
  # Dynamic allocation of a new Cube
    cube = Cube.new(10, 20, 30)
    v = cube.volume
    # ... Do what ever you have to do...
    cube.free
  end
end
```

## Methods
Methods in Rlang are defined as you would normally do in Ruby by using the `def` reserved keyword. They can be either class or instance methods.

### Method definition
A method in Rlang can either be defined in a class, a module or at the top level. In that case the method is implicitely defined within the context of the Object class as Ruby does.

Class methods must be defined using the `def self.mymethod` syntax. The `class << self ... end` form is not supported.

### Method arguments
Rlang method definition supports fixed name arguments in any number. The  *args and **args notation are not supported.

By default all arguments in Rlang are considered as being type `:I32` (a 32 bit integer). See the Type section below for more details. If your argument is of a different type you **must** explicitely state it. 
```ruby
def m_three_args(arg1, arg2, arg3)
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
Similarly you can use `result :I64` if your method is to return a double integer value or `return :Square` if you method returns an object.

With a few exceptions (see the Conditional and Iteration Structures sections below), each Rlang statements evaluate to a value. In the absence of an explicit `return` statement, a method returns the value of the last evaluated statement. In the example above defining the `MyClass` class, the method `MyClass.take_one` returns the value of `@@cvar` after decreasing it by one and `MyClass.refill` returns 100.

Rlang also gives you the ability to declare the return type of a method like this anywhere in your code.
```ruby
result :class_name, :method_name, :your_type_here
```

This result directive must be used to instruct the compiler about the return type of a method if the compiler has not yet compiled this method (e.g. the method definition is coming later in your source code) or when calling a method from another class defined in a different file not yet compiled. Keep in mind that this is only needed if the method returns something different than the default type (`:I32`).

Note: in this directive `:method_name` symbol starts with a `#` characters if it refers to an instance method. Without the `#` it refers to a class method.

For an example see the [test_def_result_type_declaration.rb](https://github.com/ljulliar/rlang/blob/master/test/rlang_test_files/test_def_result_type_declaration.rb), a Rlang file that is part of the Rlang test suite.

### Local variables
Local variable used in a method body doesn't have to be explicitely declared. They are auto-vivified the first time you assign a value to it. In some cases though, you may have to use the `local` directive as in the example below to explicitely state the type of a local variable.

```ruby
def self.m_local_var(arg1)
  local lvar: :I64, mysquare: :Square
  lvar = 10
  mysquare = @@square
  # ....
end
```
The `local` directive above instructs the compiler that `lvar` is of type `:I64` and the local variable mysquare is of type `Square`. Without it `lvar` would have been auto-vivified with the Wasm default type or `:I32`.

### Exporting a method
In WebAssembly, you can make functions visible to the outside world by declaring them in the export section. To achieve a similar result in Rlang, you can use the `export` keyword right before a method definition with an optional export name of your choice.

If no function name is specified, Rlang will build it for you. WASM exported functions are named after the class name (in lower case), the method type (class or instance) and the method name. As an example the exported method in the example above will be known to the WASM runtime as the `myclass_c_visible` function (where the `_c_` means it's a class function and `_i_` an instance method).

```ruby
class MyClass

  export
  def self.visible(arg1)
    # ...
  end

  export :seeable
  def self.visible_too(arg1)
    # ...
  end

  def self.not_visible
    # ...
  end
end
```

Note that the `export` keyword only applies to the method definition that immediately follows. In the example above `MyClass::visible` and `MyClass::visible_too` will be exported by the generated WASM module whereas `MyClass::not_visible` will not.

### Importing a method
An import statement in WebAssembly is a way to declare the signature of a method defined outside of the current WebAssembly module and then call it from your code.

Rlang has an equivalent import statement as shown in the example below:
```ruby
import :wasi_unstable, :proc_exit
def self.proc_exit(exitcode)
  arg exitcode: :I32
  result :none
end
```

The first 2 arguments of import are the imported module name and function name as in WebAssembly and then follows a regular method definition with arguments and possibly the `arg` directive to specify argument types and a `result` directive to indicate the nature of the returned value. Two points worth highlighting here:
1. The Rlang method name doesn't have to be the same as the function name in the import statement.
2. As imported function are external to your Rlang module they must be declared as class methods. This is bacause defining them as instance method would automatically pass `self` as the first argument in the method call therefore changing the signature of the method.

The example above is taken from the Rlang WASI class that defines the interface with [WASI (WebAssembly System Interface)](https::wasi.dev).


## Rlang types
The types currently supported by Rlang are:
* integers either signed long (`:I32`), unsigned long (`:UI32`), signed double (`:I64`), unsigned double (`:UI64`)
* floats single precision (`:F32`) or double precision (`:F64`)
* Classes defined in the core libraries or in your own code.

Rlang is typed language which means that the type of method argument and local variables must be explicitely declared. If a literal, local variable or argument type is not declared it is auto-vivified as type `:I32`. If you need it to be of a different type you must declare it explicitely in the method body (see above) or cast it explicitely (see below).

### Implicit type cast
Only in rare cases will you use the `local` directive in methods as Rlang does its best to infer the type of a variable from its first assigned value. As an example, in the code below, the fact that `arg1` is known to be an `:I64` type of argument is enough to auto-magically create lvar as an `:I64` local variable too.

```ruby
def m_local_var(arg1)
  arg :arg1, :I64
  lvar = arg1 * 100
  # ....
end
```

Conversely in the method below the first statement `lvar = 10` auto-vivifies `lvar` as a variable of type `:I32` (the default Rlang type). On the next line, Rlang evaluates `arg1 * 100` as an `:I64` result because `arg1` is declared as being of type `:I64`. Similarly as the type of `lvar` local variable was auto-vivified as `:I32`, the result of the expression `arg1 * 100` will be type cast from `:I64` to `:I32`. Note that such a type cast may of course result in the value being truncated and the Rlang compiler will emit a warning accordingly.

```ruby
def self.m_local_var(arg1)
  arg :arg1, :I64
  lvar = 10 # lvar is auto-vivified as :I32
  lvar = arg1 * 100
  # ....
end
```

### Implicit type cast precedence

Rlang follows the C IEC/ISO Standard to implicitely convert types. When operands of different types are mixed in arithmetic or relational operators, Rlang will conver them according to the following priority order from the highest priority to the lowest:

`:F64`, `:F32`, `:UI64`, `:I64`, `:Class`, `:UI32`, `:I32`

Let's take a few examples:
* If you use 32 bit floating point numbers and 64 bit floating point numbers in the same expression all `:F32` values will be converted to `:F64`
* Similarly if you mix `:F32` values and `:I64` values, all 64-bit integers will be converted to 32-bit floating point values before evaluating the expression
* **IMPORTANT** note that unsigned integers `:UI64` and `:UI32`have a higher priority than their signed counter part `:I64` and `:I32`. This means that when mixing signed and unsigned integer values in the same expression, the signed integers will be reinterpreted as its unsigned equivalent bitwise. As an example in this context an `:I32` with a value of -6 will be reinterpreted as an`:UI32` with a value of 4294967290. So be very cautious when mixing signed and unsigned integers as this may be give somewhat suprising results especially when using relational operators such >, <, >=,...

### Pointer arithmetics

In the types priority order mentioned above, the `:Class` type designate any value pointing to a class instance, in other word an object. This means that object pointers are values that you can process through arithmetic and relational operators like in C. A pointer to an object is a 32 bit memory address that has type casting precedence over `:UI32` and `:I32` types.

Consequently when doing some arithmetics on object pointers like an addition or a substraction the integer vale will be interpreted as a multiple of the object size as if you were moving an index over objects of the same type in memory. Again this behavior is similar to the C language.


```ruby
class MyClass
  up = Header.new
  next_hdr = up + 1 
  #...
end
```
In the example above, a new header object is created and it meory location is stored in the up variable. When adding 1 to the up variable, Rlang knows that up is of type Header and will therefore increase up not by 1 but by the size in byted of the Header Object in memory. You can see examples of pointer arithmetics in the memory allocator of Rlang in lib/malloc.rb.

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

The second example turns the value `123876` into a pointer to a `Square` object. It's pretty much like turning an integer into a pointer to a memory address in C.

For type cast a number or an expression to native type you can also use shortcuts like `100.to_I64` or `100.to_UI32`, etc...

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
## Static Data
WebAssembly allows for the definition of static data stored the WebAssembly memory. Rlang provides the ability to both define the value of static data and reference this data in your Rlang code.

You can define static data by using the **DAta** class. Note that the upper case **A** in DAta is not a typo. The Data (with lower case a) class cannot be used as it is already defined by Ruby.

Let's see a few examples of how to define and reference static data:

```ruby
# Where to implant the data in memory
# Here we start at address 2048 in memory
DAta.address = 2048
# a long (I32) integer (4 bytes in memory)
DAta[:my_integer] = 16384
# a null terminated string (13 bytes)
DAta[:my_string] = "Hello World!\00"
# Align to the next multiple of 4 in memory
DAta.align(4)
# a series of four I32 integers followed by a fifth
# integer that points to the address of :my_first_string
DAta[:my_series] = [1, 2, 3, 4, Data[:my_first_string]]
```
The last example shows how to reference an existing piece of static data using  `DAta[:label]` where `:label` is the label you used in the first place to define your data. Data reference can either be used in static data definition or anywhere in the Rlang code.

Also note that data are implanted in memory in sequential order. In the example above `:my_integer` is stored at address 2048 to 2051 (4 bytes), `:my_string` goes from 2052 to 2064 (13 bytes). Without the `DAta.align(4)` directive the next integer from `:my_series` would use bytes 2065 to 2068. Here it will actually use bytes 2068 to 2071 and the 3 bytes at address 2065 to 2067 will actually be unused.


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
    wasm wat: '(i32.mul 
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

For now, the Rlang library is very modest and containoffers the following classes and methods

* **Memory** class: provides Rlang methods like `Memory::size` and `Memory::grow` mapping directly to the WebAssembly functions of the same name (see WebAssembly specficiations)
* **Malloc** class: provides a dynamic memory manager. It is used by Rlang to instantiate new objects but you can also use it in your own code if need be.
  * Malloc.malloc(nbytes) : dynamically allocates nbytes of memory and return address of the allocated memory space or -1 if it fails
  * Malloc.free(address) : frees the block of memory at the given address
* **Object** class: provides a couple of object management method. Use `Object.free` to free an object.
* **Array32**, **Array64** : Arrays can be initialized with the usual bracket operator '[]'. When the array is initialized at compile time (statically) such as for constants or class variables you can only use integers in the array initializers (e.g.`[0, 100, 200]`). When the array is initialized at runtime (dynamically) such as in the body of a method definition you can either use integers or any Rlang object (e.g. `[ 1, 2, "A string", my_object]`)
* **String** class: string are initialized in Rlang by using a string literal like `"This is my string"`. String methods supported are very minimal for the moment. See [rlang/lib/String.rb](https://github.com/ljulliar/rlang/blob/master/lib/rlang/lib/string.rb). Feel free to improve.

As a side note, the dynamic memory allocator currently used in Rlang is shamelessly adapted from the example provided in the famous Kernigan & Richie C book 2nd edition. Take a look at the [C version](https://github.com/ljulliar/rlang/blob/master/lib/rlang/lib/malloc.c) and see how easy it is to rewrite it in [Rlang](https://github.com/ljulliar/rlang/blob/master/lib/rlang/lib/malloc.rb).

That's it! Enjoy Rlang and, as always, feedback and contributions are welcome.
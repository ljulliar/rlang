# Rubinius WebAssembly VM
# Copyright (c) 2019-2020, Laurent Julliard and contributors
# All rights reserved.

require 'test_helper'
require 'wasmer'
require_relative '../lib/builder'

# Prevent emitting warnings about toot
# many argument in sprintf
$-w = false

class RlangMallocTest < Minitest::Test

  TEST_FILES_DIR = File.expand_path('../rlang_malloc_files', __FILE__)
  RLANG_DIR = File.expand_path('../../lib/rlang/lib', __FILE__)

  # Rlang compilation options by method
  @@load_path_options = {}

  def setup
    # Compile rlang test file to WASM bytecode
    test_file = File.join(TEST_FILES_DIR,"test_malloc.rb")

    # Setup parser/compiler options
    options = {}
    options[:LOAD_PATH] = [RLANG_DIR] + (@@load_path_options[self.name.to_sym] || [])
    options[:__FILE__] = test_file
    options[:export_all] = true
    options[:memory_min] = 1
    options[:log_level] = 'FATAL'

    # Compile Wat file to WASM bytecode
    @builder = Builder::Rlang::Builder.new(test_file, nil, options)
    unless @builder.compile
      raise "Error compiling #{test_file} to #{@builder.target}"
    end

    # Instantiate wasmer runtime
    bytes = File.read(@builder.target)
    @instance = Wasmer::Instance.new(bytes)
    @exports = @instance.exports
  end

  def teardown
    @builder.cleanup
  end

  def test_initial_memory_size
    assert_equal 1, @exports.memory_c_size
  end

  def test_initial_break
    assert_equal @exports.global_c_heap, @exports.unistd_c_sbrk(0)
    assert_equal 0, @exports.global_c_heap_size
  end

  # ------------ Test sbrk ---------------

  # allocate the first 1K bloc
  def test_sbrk_1024_allocation
    assert_equal @exports.global_c_heap, @exports.unistd_c_sbrk(1024)
    assert_equal 1024, @exports.global_c_heap_size
    assert_equal @exports.global_c_heap + @exports.global_c_heap_size, @exports.unistd_c_sbrk(0)
    assert_equal 1, @exports.memory_c_size # mem size must be unchanged
  end

  # allocate a second 1024 block
  def test_sbrk_2x1024
    test_sbrk_1024_allocation

    # new break must be at offset 1024
    assert_equal @exports.global_c_heap+1024, @exports.unistd_c_sbrk(1024)
    assert_equal 2*1024, @exports.global_c_heap_size
    assert_equal @exports.global_c_heap + @exports.global_c_heap_size, @exports.unistd_c_sbrk(0)
    assert_equal 1, @exports.memory_c_size # mem size must be unchanged
  end

  # allocate 1024 plus a second 65536 - 1024 - 1 bytes block. 
  # It should still fit in the first WASM page
  def test_sbrk_1024_plus_whats_left_minus_1
    test_sbrk_1024_allocation
    wasm_mem_pages = @exports.memory_c_size
    heap_break = @exports.global_c_heap + @exports.global_c_heap_size
    # how much to allocate before an additional page is allocated
    whats_left = (wasm_mem_pages * 65536) - heap_break

    # new break must be at offset 1024
    assert_equal @exports.global_c_heap+1024, @exports.unistd_c_sbrk(whats_left-1)
    assert_equal (1024 + whats_left - 1), @exports.global_c_heap_size
    assert_equal 1, @exports.memory_c_size # mem size must be unchanged
  end

  # allocate 1024 plus a second 65536 - 1024 bytes block. 
  # It should allocate an additional WASM page
  def test_sbrk_1024_plus_whats_left
    test_sbrk_1024_allocation
    wasm_mem_pages = @exports.memory_c_size
    heap_break = @exports.global_c_heap + @exports.global_c_heap_size
    # how much to allocate before an additional page is allocated
    whats_left = (wasm_mem_pages * 65536) - heap_break

    # new break must be at offset 1024
    assert_equal @exports.global_c_heap+1024, @exports.unistd_c_sbrk(whats_left)
    assert_equal (1024 + whats_left), @exports.global_c_heap_size
    assert_equal 2, @exports.memory_c_size # mem size must be unchanged
  end

  # allocate a series of 520 blocks and check memory is not corrupted
  def test_sbrk_520_bytes_series
    ptrs = []
    count = 128
    size = 520
    0.upto(count-1) do |i|
      ptrs[i] = @exports.unistd_c_sbrk(520)
      #puts "#{i}: #{ptrs[i]}"
      # write byte pattern value i in the allocated mem
      0.upto(size-1) { |offset| @instance.memory.uint8_view[ptrs[i]+offset] = i}
    end
  
    # check that no block was corrupted
    ptrs.each_with_index do |ptr, i|
      0.upto(size-1) { |offset| assert_equal i, @instance.memory.uint8_view[ptr+offset] }
    end

    assert_equal 2, @exports.memory_c_size
  end

  # ------------ Test morecore -------------
  def test_morecore_on_empty_list
    hdr_ptr = @exports.malloc_c_morecore(2) # 2 units = 16 bytes
    log_free_chain("morecore 2 units")
    assert_equal 0, hdr_ptr
  end


  # ------------ Test malloc ---------------

  # malloc'ing 8 bytes should actually allocate 8+8 bytes as above
  def test_malloc_first_8_bytes
    # malloc'ed space should be right after the header (hence the +8)
    ptr = @exports.malloc_c_malloc(8)

    # The first malloc triggers NALLOC * 8 bytes allocated to heap
    assert_equal 8*1024, @exports.global_c_heap_size 
    assert_equal @exports.global_c_heap + @exports.global_c_heap_size, \
                 @exports.unistd_c_sbrk(0)

    # The 8 bytes allocated is taken from the end of the free block
    #puts "ptr: #{ptr}"
    assert_equal @exports.unistd_c_sbrk(0) - 8, ptr

    # Free chain should look like this
    # (replace base_addr with the memory address of the @@base Header)
    # freep: 20 -> @20 (ptr: 10024, size: 0) -> @10024 (ptr: 20, size: 1022)
    #
    # base_addr value below may vary depending on the modification brought to
    # Rlang core library
    base_addr = 92
    log_free_chain("after malloc")
    
    freep = @exports.malloc_c_freep
    assert_equal base_addr, freep
    assert_equal @exports.global_c_heap, @exports.header_i_ptr(freep)
    assert_equal 0, @exports.header_i_size(freep)
    assert_equal freep, @exports.header_i_ptr(@exports.header_i_ptr(freep))
    assert_equal 1024 - 2, @exports.header_i_size(@exports.header_i_ptr(freep))
  end


  # malloc'ing 4 bytes should also allocate 8+8 bytes as above
  def test_malloc_first_4_bytes
    # malloc'ed space should be right after the header (hence the +8)
    ptr = @exports.malloc_c_malloc(4)

    # The first malloc triggers NALLOC * 8 bytes allocated to heap
    assert_equal 8*1024, @exports.global_c_heap_size 
    assert_equal @exports.global_c_heap + @exports.global_c_heap_size, \
                 @exports.unistd_c_sbrk(0)

    # The 8 bytes allocated is taken from the end of the free block
    #puts "ptr: #{ptr}"
    assert_equal @exports.unistd_c_sbrk(0) - 8, ptr

    # Free chain should look like this
    # freep: 20 -> @20 (ptr: 10024, size: 0) -> @10024 (ptr: 20, size: 1022)
    log_free_chain("after malloc")
  end

  # malloc a series of 512 bytes up to growing the WASM memory
  # by one more page
  def test_malloc_512_bytes_series
    ptrs = []
    count = 128
    size = 512
    0.upto(count-1) do |i|
      ptrs[i] = @exports.malloc_c_malloc(size)
      #puts "#{i}: #{ptrs[i]}"
      # write byte pattern value i in the allocated mem
      0.upto(size-1) { |offset| @instance.memory.uint8_view[ptrs[i]+offset] = i}
    end

    # check that no block was corrupted
    ptrs.each_with_index do |ptr, i|
      0.upto(size-1) { |offset| assert_equal i, @instance.memory.uint8_view[ptr+offset] }
    end

    assert_equal 2, @exports.memory_c_size
    log_free_chain("after malloc")
  end


  # ------------ Test free ---------------

  def test_free_first_block
    ptr = @exports.malloc_c_malloc(24)
    # The 24 bytes allocated are taken from the end of the free block
    #puts "ptr: #{ptr}"
    assert_equal @exports.unistd_c_sbrk(0) - 24, ptr
    log_free_chain("after malloc")

    @exports.malloc_c_free(ptr)
    # after freeing the only allocated block the free chain looks like this
    # The first free block in the chain should be 1024 units again as before the malloc
    # freep: 10024 -> @10024 (ptr: 20, size: 1024) -> @20 (ptr: 10024, size: 0)
    log_free_chain("after free")
    assert_equal 1024, @exports.header_i_size(@exports.malloc_c_freep)
  end

  def test_free_first_block_of_two
    # allocate first block and second block
    ptr1 = @exports.malloc_c_malloc(24)  # 18192
    ptr2 = @exports.malloc_c_malloc(128) # 18056
    #puts "#{ptr1}, #{ptr2}"
    log_free_chain("after 2 malloc")

    # free first block
    @exports.malloc_c_free(ptr1)
    # after freeing the only allocated block the free chain looks like this
    # freep: 10024 -> @10024 (ptr: 18184, size: 1003) -> @18184 (ptr: 20, size: 4) -> @20 (ptr: 10024, size: 0)    @exports.malloc_c_free(ptr1)
    log_free_chain("after free")
    assert_equal ptr1-8, (fp = find_free_block(ptr1-8))
    assert_equal 4, @exports.header_i_size(fp) # a 4 units block should be free'd
  end

  def test_free_first_block_of_two_and_alloc_smaller
    # allocate first block and second block
    ptr1 = @exports.malloc_c_malloc(24)  # 18192
    ptr2 = @exports.malloc_c_malloc(128) # 18056

    # free first block and alloc smaller
    @exports.malloc_c_free(ptr1)
    log_free_chain("after free ptr1")
    ptr3 = @exports.malloc_c_malloc(16)
    log_free_chain("after smaller alloc ptr2")

    assert_equal ptr1+(24-16), ptr3
  end

  def test_free_all_allocated_blocks
    # allocate first block and second block
    ptr1 = @exports.malloc_c_malloc(32)
    ptr2 = @exports.malloc_c_malloc(128)
    ptr3 = @exports.malloc_c_malloc(256)
    ptr4 = @exports.malloc_c_malloc(512)
    log_free_chain("after 4 malloc")

    # After malloc's The free block size should 904 units long
    assert_equal @exports.global_c_heap, (fp = find_free_block(@exports.global_c_heap))
    assert_equal 1024 - (32+8+128+8+256+8+512+8)/8, @exports.header_i_size(fp)

    # free first block and alloc smaller
    @exports.malloc_c_free(ptr1)
    log_free_chain("after free ptr1")
    @exports.malloc_c_free(ptr2)
    log_free_chain("after free ptr2")
    @exports.malloc_c_free(ptr3)
    log_free_chain("after free ptr3")
    @exports.malloc_c_free(ptr4)
    log_free_chain("after free ptr4")

    # After free's The free block size should be back to 1024 units
    assert_equal @exports.global_c_heap, (fp = find_free_block(@exports.global_c_heap))
    assert_equal 1024, @exports.header_i_size(fp)
  end


  # ------- malloc test helpers --------

  def log_free_chain(label)
    p_base = @exports.malloc_c_freep()
    printf("Free chain in #{caller[0][/`.*'/][1..-2]} - %s\n", label)
    printf("freep: %d", p_base)
    p = p_base
    loop do
      #printf(" -> @%d (ptr: %d, size: %d)", p, @exports.header_i_ptr(p), @exports.header_i_size(p))
      printf(" -> @%d (ptr: %d, size: %d)", p, @exports.header_i_ptr(p), @exports.header_i_size(p))
      p = @exports.header_i_ptr(p)
      break if (p == 0 || p == p_base)
    end
    print("\n\n")
  end

  def find_free_block(address)
    p_base = @exports.malloc_c_freep()
    p = p_base
    found_block = nil
    loop do
      break if (found_block = p) == address
      p = @exports.header_i_ptr(p)
      break if (p == 0 || p == p_base)
    end
    found_block
  end
end
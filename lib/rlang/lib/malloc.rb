# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.
#
# This is a simple memory allocator derived
# from K&R C Language 2nd Edition p 185-189
#
# For a detailed explanation of the allocator code see
# https://gnuchops.wordpress.com/2013/02/26/memory-allocator-for-embedded-system-k-r-ritchie-book/

require 'rlang/lib/memory'
require 'rlang/lib/unistd'

# minimum number of units to request
$NALLOC = 1024

# Header structure at beginning of each allocated
# memory block
# (this structure is also called a unit and the memory
# allocation will always happen on a boundary aligned
# with the most restrictive type of WASM that is to say i64)
# As the struct below is 8 byte long and i64 is too our
# unit memory allocation size will be 8 bytes here.
# 
# struct {
#   header *ptr;  /* next block if on free list */ => 4 bytes in WASM
#   unsigned size /* size of this block */         => 4 bytes in WASM
# } header;
#

# Allocate some unused memory space to make 
# sure so that freep doesn't point to memory
# address 0 because it has a sepcial meaning
# Allocate 20 bytes (5 x I32 integers)
DAta[:dummy_malloc_data] = [0, 0, 0, 0, 0]

class Header
  attr_accessor :ptr, :size
  attr_type ptr: :Header, size: :I32
end
    
class Malloc

  @@base = Header.new          # empty list to get started
  @@freep = 0.cast_to(:Header) # start of free list

  # declare ahead of time because is used in
  # the code before it is actually defined
  result :Malloc, :free, :nil

# -------- Dynamic Memory Allocator Functions -----------

  # malloc: allocate n bytes of memory and return pointer
  # to data block
  def self.malloc(nbytes)
    local p: :Header, prevp: :Header

    # allocate memory by chunk of units (the unit is
    # the size of a Header object here)
    # units = (nbytes+sizeof(Header)-1)/sizeof(Header) + 1;
    nunits = (nbytes + Header._size_ - 1) / Header._size_ + 1

    # No free list yet. Initialize it.
    if (prevp = @@freep) == 0 
      @@base.ptr = @@freep = prevp = @@base
      @@base.size = 0
    end

    # scan the free list for a big enough free block
    # (first in list is taken)
    p = prevp.ptr
    while true
      if (p.size >= nunits) # big enough
        if (p.size == nunits) 
          # exactly the requested size
          prevp.ptr = p.ptr
        else
          # bigger free block found
          # Allocate tail end
          p.size -= nunits
          p += p.size
          p.size = nunits
        end
        @@freep = prevp
        # TODO: we should actually cast to default WASM type
        return (p + 1).cast_to(:I32)
      end

      # wrapped around free list
      if p == @@freep
        if (p = self.morecore(nunits)) == 0
          return 0
        end
      end

      prevp = p; p = p.ptr
    end

    # Rlang specific: remember that while construct 
    # doesn't evaluate to a value so we must add an
    # explicit return here.
    # However we should **never** get there so return NULL
    return 0
  end
  
  # morecore: ask system for more memory
  def self.morecore(nu)
    result :Header
    local up: :Header

    nu = $NALLOC if nu < $NALLOC
    cp = Unistd::sbrk(nu * Header._size_)
    return 0 if cp == -1 # no space at all

    up = cp.cast_to(:Header)
    up.size = nu
    self.free((up + 1).to_I32)
    return @@freep
  end

  # Free memory block
  def self.free(ap)
    arg ap: :I32
    result :none
    local bp: :Header, p: :Header

    # NULL is a special value used for
    # all Rlag object instances that doesn't 
    # have any instance variables and therefore
    # doesn't use any memory
    return if ap == 0

    bp = ap.cast_to(:Header) - 1 # point to block header
    p = @@freep
    while !(bp > p && bp < p.ptr)
      # freed block at start or end of arena 
      break if (p >= p.ptr && (bp > p || bp < p.ptr))
      p = p.ptr
    end

    if (bp + bp.size == p.ptr)
      # join to upper nbr
      bp.size += p.ptr.size
      bp.ptr = p.ptr.ptr
    else
      bp.ptr = p.ptr
    end

    if (p + p.size == bp)
      # join to lower nbr
      p.size += bp.size
      p.ptr = bp.ptr
    else
      p.ptr = bp
    end
    @@freep = p
  end

end
# Direct-Mapped Cache Memory Design

## Overview
This project implements a **direct-mapped cache memory** using **Verilog** to demonstrate how cache memory reduces main memory access latency. The design models basic cache behavior including address breakdown, hit/miss detection, and read/write operations, providing a clear understanding of memory hierarchy concepts.

## Background
Modern processors operate much faster than main memory, creating a performance gap known as the **memory wall**. Cache memory bridges this gap by storing frequently accessed data closer to the CPU. A direct-mapped cache offers a simple and fast caching technique where each memory block maps to exactly one cache line.

## Cache Architecture
- Fixed mapping of memory blocks to cache lines  
- Address divided into **Tag, Index, and Offset** fields  
- Each cache line stores:
  - Data
  - Tag
  - Valid bit
  - Dirty bit

## Supported Operations
### Read Operation
- **Cache Hit:** Data is returned directly from the cache  
- **Cache Miss:** Data is fetched from main memory and placed into the cache  

### Write Operation
- Supports **Write-Through** and **Write-Back** policies  
- Handles both hit and miss scenarios appropriately  

## Implementation Details
- Written in **Verilog HDL**
- Includes comparator logic for tag matching  
- FSM-based control logic manages cache access and memory operations  
- Main memory module simulates cache fills and evictions  

## Verification
- Functionality verified using **timing diagrams**  
- **Waveform analysis** confirms correct behavior for hit, miss, read, and write cases

## Key Concepts Covered
- Memory hierarchy  
- Cache mapping techniques  
- Hit and miss handling  
- Verilog-based hardware design  
- Timing and waveform analysis  

## Future Improvements
- Set-associative cache implementation  
- Performance comparison with fully associative cache  
- Parameterized cache size and block size  

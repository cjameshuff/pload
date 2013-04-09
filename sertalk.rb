#!/usr/bin/env ruby

require 'ftdi'

# ******************************************************************************
module Ftdi
    class Context
        def try_read_n(len)
            chunksize = read_data_chunksize
            p = FFI::MemoryPointer.new(:char, chunksize)
            bytes_read = Ftdi.ftdi_read_data(ctx, p, len)
            check_result(bytes_read)
            r = p.read_bytes(bytes_read)
            r.force_encoding("ASCII-8BIT")  if r.respond_to?(:force_encoding)
            r
        end # try_read_n()

        def read_n(len, timeout)
            data = ""
            tstart = Time.now
            while(data.length < len && Time.now - tstart < timeout)
                data += try_read_n(len - data.length)
            end
            data
        end # read_serial()

        def read_line(sep = '\n')
            data = ""
            while(data[-1] != sep)
                data += try_read_n(1)
            end
            data
        end # read_serial()
        
        def latency_timer=(new_latency_timer)
            check_result(Ftdi.ftdi_set_latency_timer(ctx, new_latency_timer))
            new_latency_timer
        end
        
    end # class Context
    
    attach_function :ftdi_set_latency_timer, [:pointer, :uchar], :int
end # module Ftdi


module PapilioCtl
    

OPCODE_SYNC        = 0x01
OPCODE_ACK         = 0x02
OPCODE_POLL_STATUS = 0x03
OPCODE_VERSION     = 0x04

OPCODE_READBUFFER  = 0x08
OPCODE_WRITEBUFFER = 0x09
OPCODE_CRCBUFFER   = 0x0A

#     constant OpCode_DFlash_Cmd:       std_logic_vector(7 downto 0) := X"30";
#     constant OpCode_DFlash_ChipErase: std_logic_vector(7 downto 0) := X"31";
#     constant OpCode_DFlash_WriteAddr: std_logic_vector(7 downto 0) := X"35";
#     constant OpCode_DFlash_WriteData: std_logic_vector(7 downto 0) := X"36";
#     constant OpCode_DFlash_ReadAddr:  std_logic_vector(7 downto 0) := X"38";
#     constant OpCode_DFlash_ReadData:  std_logic_vector(7 downto 0) := X"39";
OPCODE_FLASH_CHIPERASE = 0x31
OPCODE_FLASH_WRITEADDR = 0x35
OPCODE_FLASH_WRITEDATA = 0x36
OPCODE_FLASH_READADDR  = 0x38
OPCODE_FLASH_READDATA  = 0x39

RESP_ERROR = 0xFF

# ******************************************************************************

def comp_crc(data)
    if(data.is_a? String)
        data = data.bytes
    end
    crc = 0xFFFF
    data.each {|x|
        crc = crc ^ (x << 8)
        8.times {
            crc = ((crc & 0x8000) == 0x8000)? ((crc << 1) ^ 0x1021) : (crc << 1);
            crc = crc & 0xFFFF
#             puts "%04X"%(crc & 0xFFFF)
        }
    }
    crc & 0xFFFF
end


# ******************************************************************************

class Papilio
    include PapilioCtl
    
    def initialize()
        @ftdi = Ftdi::Context.new
        @ftdi.interface = :interface_b
        @ftdi.usb_open(0x0403, 0x6010)
        begin
            @ftdi.usb_reset
            
            @ftdi.latency_timer = 1 # needed to prevent lost data in large reads
            
            #     puts "setting up comm params"
            @ftdi.baudrate = 2000100
            @ftdi.set_line_property2(:bits_8, :stop_bit_1, :none, :break_off)
            @ftdi.flowctrl = Ftdi::SIO_DISABLE_FLOW_CTRL
        rescue Ftdi::Error => e
            $stderr.puts e.to_s
            @ftdi.usb_close()
            raise e
        end
        
        comm_sync()
    end # initialize
    
    def get_ack()
        ack = @ftdi.read_n(7, 1.0)
        if(is_nack(ack))
            puts "Received NACK"
            exit
        elsif(ack.length < 7)
            puts "Short response: #{binstring(ack)}"
            exit
        else
            crc = comp_crc(ack[0, 5])
            rxcrc = get_packet_crc(ack)
            if(crc != rxcrc)
                puts "Ack error"
                puts "Packet: #{binstring(ack)}"
                puts "Expected CRC: %04X, got %04X"%[crc, rxcrc]
                exit
            end
        end
        ack
    end
    
    def send_cmd(cmd, args)
        pkt = [cmd, args].pack("CN")
        @ftdi.write_data(pkt)
        @ftdi.write_data([comp_crc(pkt)].pack("n"))
    end
    
    def write_buffer(start_loc, data)
        # WRITEBUFFER is only acked after data has been sent
        # ack contains CRC of data as received.
        send_cmd(OPCODE_WRITEBUFFER, (start_loc << 16) | (data.length + start_loc - 1))
        @ftdi.write_data(data)
        ack = get_ack()
        crc = comp_crc(data)
        rxcrc = get_payload_crc(ack)
        if(crc != rxcrc)
            puts "Buffer write error"
            puts "Packet: #{binstring(ack)}"
            puts "Expected CRC: %04X, got %04X"%[crc, rxcrc]
            exit
        end
    end
    
    def read_buffer(start_loc, length)
        # READBUFFER is acked after data. response is data + ack packet with CRC
        send_cmd(OPCODE_READBUFFER, (start_loc << 16) | (length + start_loc - 1))
        result = @ftdi.read_n(length, 1.0)
        if(is_nack(result))
            puts "Received NACK"
            exit
        else
            ack = get_ack()
            crc = comp_crc(result)
            rxcrc = get_payload_crc(ack)
            if(crc != rxcrc)
                puts "Buffer read error"
                puts "Packet: #{binstring(ack)}"
                puts "Expected CRC: %04X, got %04X"%[crc, rxcrc]
                exit
            end
        end
        result
    end
    
    def comm_sync()
        @ftdi.write_data((0..4096).map{|x| 0x00})
        dump = @ftdi.read_n(4096, 0.5)
        puts "#{dump.length} bytes read after resync"
        
        (1..10).each do |x|
            send_cmd(OPCODE_SYNC, x)
            puts "Sync #{x}: #{binstring(get_ack())}"
        end
    end
    
    def ping()
        send_cmd(OPCODE_SYNC, x)
        ack = get_ack()
        puts "Sync #{x}: #{binstring(ack)}"
    end
    
    def poll_status()
        send_cmd(OPCODE_POLL_STATUS, 0x00000000)
        ack = get_ack()
#         puts "Status response: #{binstring(ack)}"
        ack[1, 4].unpack("N")[0]
    end
    
    def wait_busy(timeout = 1)
        start_time = Time.now;
        while(1)
            status = poll_status()
            if(!status_busy(status))
                break
            elsif(Time.now - start_time > timeout)
                puts "Timeout in wait_busy"
                exit
            end
        end
    end
    
    def flash_chip_erase()
        # Must be in write mode to erase chip
        puts "Setting write mode"
        send_cmd(OPCODE_FLASH_WRITEADDR, 0x00000000)
        ack = get_ack()
        puts "Erasing chip"
        send_cmd(OPCODE_FLASH_CHIPERASE, 0x00000000)
        ack = get_ack()
        
        wait_busy()
    end
    
    # Chunk sizes up to 65536 B are supported by the protocol.
    # Read chunk size should be limited to around 256 B to avoid FIFO overflow
    # issues.
    def flash_read_chunk(flash_addr, buf_start_loc, length)
        puts "Setting read address"
        send_cmd(OPCODE_FLASH_READADDR, flash_addr)
        ack = get_ack()
        wait_busy()
        
        puts "Reading data to buffer"
        send_cmd(OPCODE_FLASH_READDATA, (buf_start_loc << 16) | (length + buf_start_loc - 1))
        ack = get_ack()
        wait_busy()
        
        puts "Reading buffer"
        read_buffer(buf_start_loc, length)
    end
    
    # Chunk sizes up to 65536 B are supported by the protocol.
    # Write chunk size should be no larger than 2048 B for implementations using
    # a single-BRAM buffer.
    def flash_write_chunk(data, flash_addr, buf_start_loc)
        puts "Writing %d B to %08X"%[data.length, flash_addr]
        write_buffer(buf_start_loc, data)
        
        send_cmd(OPCODE_FLASH_WRITEADDR, flash_addr)
        ack = get_ack()
        
        send_cmd(OPCODE_FLASH_WRITEDATA, (buf_start_loc << 16) | (data.length + buf_start_loc - 1))
        ack = get_ack()
        wait_busy()
    end
    
    def flash_file(fname, offset = 0)
        fin = File.new(fname, "rb")
        field0_len = fin.read(2).unpack("n")[0] # some untagged 9 byte field?
        field0 = fin.read(field0_len)
        field1 = fin.read(2) # ??? 2 bytes here that don't fit any pattern.
        
        while(!fin.eof?)
            tag = fin.read(1)
            case tag
            when "a"
                field_len = fin.read(2).unpack("n")[0]
                design_name = fin.read(field_len)
                puts "Design name: #{design_name}"
            when "b"
                field_len = fin.read(2).unpack("n")[0]
                part_name = fin.read(field_len)
                puts "Part name: #{part_name}"
            when "c"
                field_len = fin.read(2).unpack("n")[0]
                bitfile_date = fin.read(field_len)
                puts "Date: #{bitfile_date}"
            when "d"
                field_len = fin.read(2).unpack("n")[0]
                bitfile_time = fin.read(field_len)
                puts "Time: #{bitfile_time}"
            when "e"
                field_len = fin.read(4).unpack("N")[0]
                puts "data length: #{field_len}"
                bitfile_data = fin.read(field_len)
                break
            end # case tag
        end
        
        if(bitfile_data.length % 2 == 1)
            # odd data length, need to write even number of bytes
            bitfile_data.push(0xFF)
        end
        
        start_time = Time.now;
        
        send_cmd(OPCODE_FLASH_WRITEADDR, offset)
        ack = get_ack()
        
        chunk_size = 1024
        buf_start_loc = 0
        bitfile_addr = 0
        
        # Load first chunk into "hot" buffer
        chunk = bitfile_data[bitfile_addr, chunk_size]
        puts "Writing %d B to %08X"%[chunk.length, bitfile_addr + offset]
        write_buffer(buf_start_loc, chunk)
        bitfile_addr += chunk_size
        
        wait_time = 0
        
        while(bitfile_addr < bitfile_data.length)
            # wait for writes in progress to finish and swap buffers
            wait_start_time = Time.now;
            wait_busy()
            wait_time += Time.now - wait_start_time
            
            # Write "hot" buffer
            send_cmd(OPCODE_FLASH_WRITEDATA, (buf_start_loc << 16) | (chunk.length + buf_start_loc - 1))
            ack = get_ack()
            
            # Load "cold" buffer while write is in progress
            buf_start_loc = (buf_start_loc + chunk_size) % 2048
            chunk = bitfile_data[bitfile_addr, chunk_size]
            puts "Writing %d B to %08X"%[chunk.length, bitfile_addr + offset]
            write_buffer(buf_start_loc, chunk)
            
            bitfile_addr += chunk_size
        end
        # Write last buffer
        wait_busy()
        send_cmd(OPCODE_FLASH_WRITEDATA, (buf_start_loc << 16) | (chunk.length + buf_start_loc - 1))
        ack = get_ack()
        
        # switch flash back to read mode (disables inadvertent flash writes)
        send_cmd(OPCODE_FLASH_READADDR, 0x000000)
        ack = get_ack()
        
        end_time = Time.now;
        puts "Completed in %5f s"%[(end_time - start_time)]
        puts "Wait time: %5f s"%[wait_time]
    end
    
  private
    def status_busy(status)
        (status & 0x00000001) == 0x00000001
    end
    
    # Get the CRC from the given packet
    def is_nack(pkt)
        pkt.length == 1 && pkt[0].unpack("C")[0] == RESP_ERROR
    end
    def get_packet_crc(pkt)
        pkt[-2, 2].unpack("n")[0]
    end
    
    # Get the payload CRC from a buffer read/write ACK
    def get_payload_crc(ack)
        ack[3, 2].unpack("n")[0]
    end
end # class Papilio

end # module PapilioCtl

# ******************************************************************************

def binstring(data)
    if(data.is_a? String)
        data = data.bytes
    end
    (0..(data.length + 15)/16 - 1).map do |row|
        data[row*16, 16].map{|x| "%02X"%x}.join(", ")
    end.join(",\n")
end


begin
    p = PapilioCtl::Papilio.new
    
    puts "status: 0x%08X"%p.poll_status()
    
    p.flash_chip_erase()
    p.flash_file("proj/pload500k/Main.bit")
    
#     p.flash_write_chunk((0..255).map{|x| x & 0xFF}, 0x000000, 0x0000)
    
    result = p.flash_read_chunk(0x000000, 0x0000, 256)
    puts "Readback: #{result.length} B"
    puts binstring(result)
    
    
#     test_data = (0..255).map{|x| x & 0xFF}
#     test_data = (0..2047).map{|x| x & 0xFF}
#     test_data = (0..2047).map{|x| x/8}

#     ack = p.write_buffer(0x0000, test_data)
#     puts "Wrote: #{test_data.length} B"
#     puts binstring(test_data)
#     
#     result = p.read_buffer(0x0080, 256)
#     puts "Readback: #{result.length} B"
#     puts binstring(result)
#     
#     ack = p.write_buffer(0x0100, (0..255).map{|x| 0xBB})
#     
#     result = p.read_buffer(0x0080, 256)
#     puts "Readback: #{result.length} B"
#     puts binstring(result)
    
    
rescue Ftdi::Error => e
    $stderr.puts e.to_s
end



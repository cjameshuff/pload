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
OPCODE_SETADDRESS  = 0x10
OPCODE_READBUFFER  = 0x20
OPCODE_WRITEBUFFER = 0x21

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
            
            @ftdi.latency_timer = 2 # needed to prevent lost data in large reads
            
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
        elsif(ack.length < 7)
            puts "Short response: #{binstring(ack)}"
        else
            crc = comp_crc(ack[0, 5])
            rxcrc = get_packet_crc(ack)
            if(crc != rxcrc)
                puts "Ack error"
                puts "Packet: #{binstring(ack)}"
                puts "Expected CRC: %04X, got %04X"%[crc, rxcrc]
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
        end
    end

    def read_buffer(start_loc, length)
        # READBUFFER is acked after data. response is data + ack packet with CRC
        send_cmd(OPCODE_READBUFFER, (start_loc << 16) | (length + start_loc - 1))
        result = @ftdi.read_n(length, 1.0)
        if(is_nack(result))
            puts "Received NACK"
        else
            ack = get_ack()
            crc = comp_crc(result)
            rxcrc = get_payload_crc(ack)
            if(crc != rxcrc)
                puts "Buffer read error"
                puts "Packet: #{binstring(ack)}"
                puts "Expected CRC: %04X, got %04X"%[crc, rxcrc]
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
  private
    # Get the CRC from the given packet
    def is_nack(pkt)
        pkt[0].unpack("C")[0] == RESP_ERROR
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
    
    test_data = (0..255).map{|x| x & 0xFF}
#     test_data = (0..2047).map{|x| x & 0xFF}
#     test_data = (0..2047).map{|x| x/8}

    ack = p.write_buffer(0x0000, test_data)
    puts "Wrote: #{test_data.length} B"
    puts binstring(test_data)
    
    result = p.read_buffer(0x0080, 256)
    puts "Readback: #{result.length} B"
    puts binstring(result)
    
    ack = p.write_buffer(0x0100, (0..255).map{|x| 0xBB})
    
    result = p.read_buffer(0x0080, 256)
    puts "Readback: #{result.length} B"
    puts binstring(result)
    
    
rescue Ftdi::Error => e
    $stderr.puts e.to_s
end


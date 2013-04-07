
commengine.vhd implements a simple master/slave control protocol.
All transactions are initiated by the master.
Most transactions are short packets with the following format:

CMD:8 ARGS:32 CRC:16 [PAYLOAD]
No-payload packets are of fixed size: 7 bytes.

NACK due to CRC mismatch is single byte response of Resp_Error. The master responds
to such events by sending a string of 0x00 bytes to resynchronize the slave.

ACK is simply a repetition of the command packet, possibly with data in the ARGS field.

The master may also read, write, and check the CRC of arbitary ranges in a RAM buffer
of up to 65536 B.

-------------------------------------
OpCode_WriteBuffer: Write to range of buffer.
Slave responds with CRC of written data.

  in: (OpCode_WriteBuffer START_LOC:16 LAST_LOC:16)
  in2: (N bytes payload)
  out: (OpCode_WriteBuffer UNUSED:16 PAYLOAD_CRC:16)

-------------------------------------
OpCode_ReadBuffer: Read range from buffer.
  in: (OpCode_ReadBuffer START_LOC:16 LAST_LOC:16)
  out: (N bytes payload)
  out 2: (OpCode_ReadBuffer UNUSED:16 PAYLOAD_CRC:16)

-------------------------------------
OpCode_CRC_Buffer: Identical to OpCode_ReadBuffer, but does not transmit the data.
  in: (OpCode_ReadBuffer START_LOC:16 LAST_LOC:16)
  out: (OpCode_ReadBuffer UNUSED:16 PAYLOAD_CRC:16)






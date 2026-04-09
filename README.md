# DPS310_I2C
DPS310_I2C is basically the VHDL code for writing and reading DPS310.\
This can be treated as a generic I2C protocol (idk , need to test).


# Files :
**UART_TOP**     : Main Top code for all the integration\
**DPS310_main**  : Reading and Writing master with arrays containing the Reading Addresses and Writing Addresses along with the writing data.\
**DPS310_write** : Writing FSM to a Register with a handshake signal in return.\
**DPS310_read**  : Reading FSM of from a Register with a handshake signal in return.\
**Python File**  : To read the temp and pressure periodically (1 sec)

# Data Stream and Commands :
1 : INITIALIZE\
2 : GET THE COEFFICIENTS\
3 : DATA


Received: **31 0e 4e e2 13 cc 9f 38 94 f4 2e 04 c2 dd 73 00 55 fb 8d**\
First byte is the command returned directly.\
Then comes the Register values from 0x10 to 0x21 in series.

Received: **33 00 00 00 00 00 00 00 00 00 00 __ __ __ __ __ __  10 10**\
Values come from Register 0x00 to 0x05 in series followed by the 2 times value of Register 0x0D (value supposed to be 0x10)





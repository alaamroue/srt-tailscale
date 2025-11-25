# Based on documentation:
# INA219 Zerø-Drift, Bidirectional Current/Power Monitor With I2C Interface

import smbus
import time
import math

# INA219 I2C address on Waveshare UPS HAT (check with `i2cdetect` if unsure):
I2C_BUS                  = 1           # Default I2C bus
INA219_ADDR              = 0x42        # INA219 address, Run to check: i2cdetect 1

# INA219 register addresses (from datasheet)
REG_CONFIG               = 0x00        # Configuration register (R/W)
REG_SHUNTVOLTAGE         = 0x01        # Shunt voltage register (R)
REG_BUSVOLTAGE           = 0x02        # Bus voltage register (R)
REG_POWER                = 0x03        # Power register (R)
REG_CURRENT              = 0x04        # Current register (R)
REG_CALIBRATION          = 0x05        # Calibration register (R/W)

# Operating Mode: Table 6 (p.20)
#   These select what the chip measures and how often
class Mode:
    BIT_FIELD = 0                      # Bits 0-2
    POWERDOW             = 0x00        # Power-down
    SVOLT_TRIGGERED      = 0x01        # Shunt voltage, triggered
    BVOLT_TRIGGERED      = 0x02        # Bus voltage, triggered
    SANDBVOLT_TRIGGERED  = 0x03        # Shunt and bus, triggered
    ADCOFF               = 0x04        # ADC off (disabled)
    SVOLT_CONTINUOUS     = 0x05        # Shunt voltage, continuous
    BVOLT_CONTINUOUS     = 0x06        # Bus voltage, continuous
    SANDBVOLT_CONTINUOUS = 0x07        # Shunt and bus, continuous

# Shunt ADC Resolution: Table 5 (p.20)
# speed vs noise trade-off for the shunt voltage. (More sample -> more time but less noise)
class SADCResolution:
    BIT_FIELD = 3                      # Bits 3-6
    ADCRES_9BIT_1S       = 0b0000      # Single conversion: 9  bit        84us
    ADCRES_10BIT_1S      = 0b0001      # Single conversion: 10 bit        148us
    ADCRES_11BIT_1S      = 0b0010      # Single conversion: 11 bit        276us
    ADCRES_12BIT_1S      = 0b1000      # 12 bit Averaging, Sampling: 1    532us
    ADCRES_12BIT_2S      = 0b1001      # 12 bit Averaging, Sampling: 2    1.06ms
    ADCRES_12BIT_4S      = 0b1010      # 12 bit Averaging, Sampling: 4    2.13ms
    ADCRES_12BIT_8S      = 0b1011      # 12 bit Averaging, Sampling: 8    4.26ms
    ADCRES_12BIT_16S     = 0b1100      # 12 bit Averaging, Sampling: 16   8.51ms
    ADCRES_12BIT_32S     = 0b1101      # 12 bit Averaging, Sampling: 32   17.02ms
    ADCRES_12BIT_64S     = 0b1110      # 12 bit Averaging, Sampling: 64   34.05ms
    ADCRES_12BIT_128S    = 0b1111      # 12 bit Averaging, Sampling: 128  68.10ms

# Bus ADC Resolution: Table 5 (p.20)
# speed vs noise trade-off for the bus voltage. (More sample -> more time but less noise)
class BADCResolution:
    BIT_FIELD = 7                      # Bits 7-10
    ADCRES_9BIT_1S       = 0b0000      # Single conversion: 9  bit        84us
    ADCRES_10BIT_1S      = 0b0001      # Single conversion: 10 bit        148us
    ADCRES_11BIT_1S      = 0b0010      # Single conversion: 11 bit        276us
    ADCRES_12BIT_1S      = 0b1000      # 12 bit Averaging, Sampling: 1    532us
    ADCRES_12BIT_2S      = 0b1001      # 12 bit Averaging, Sampling: 2    1.06ms
    ADCRES_12BIT_4S      = 0b1010      # 12 bit Averaging, Sampling: 4    2.13ms
    ADCRES_12BIT_8S      = 0b1011      # 12 bit Averaging, Sampling: 8    4.26ms
    ADCRES_12BIT_16S     = 0b1100      # 12 bit Averaging, Sampling: 16   8.51ms
    ADCRES_12BIT_32S     = 0b1101      # 12 bit Averaging, Sampling: 32   17.02ms
    ADCRES_12BIT_64S     = 0b1110      # 12 bit Averaging, Sampling: 64   34.05ms
    ADCRES_12BIT_128S    = 0b1111      # 12 bit Averaging, Sampling: 128  68.10ms

# Gain amplifier: Table 4 (p.20)
# PGA gain for shunt voltage
class Gain:
    BIT_FIELD = 11                     # Bits 11-12
    DIV_1_40MV           = 0b00        # shunt prog. gain set to  1, ±40 mV range
    DIV_2_80MV           = 0b01        # shunt prog. gain set to /2, ±80 mV range
    DIV_4_160MV          = 0b10        # shunt prog. gain set to /4, ±160 mV range
    DIV_8_320MV          = 0b11        # shunt prog. gain set to /8, ±320 mV range

# Bus Voltage Range: (p.19)
class VoltageRange:
    BIT_FIELD = 13                     # Bit 13
    RANGE_16V            = 0b0         # 16V Full Scale Range
    RANGE_32V            = 0b1         # 32V Full Scale Range

# BIT 14 IS RESERVED

# Bus Voltage Range (p.19)
class ResetBit:
    BIT_FIELD = 15                     # Bit 15
    NO_RESET             = 0b0         # Does nothing
    RESET                = 0b1         # Generate system reset


# Constants
CALIBRATION_SCALER_CONST = 0.04096     # from datasheet page 12
MAX_16BIT_REG            = 32767       # A 16 bit register can hold numbers between -32768 and 32767

# Desired operating parameters
SHUNT_RESISTOR_OHMS      = 0.01        # The schematic shows 0.1 Ω but this is a mistake? 0.01 Ω (From board)
MAX_EXPECTED_AMPS        = 2.0         # Max expected current = 2 A


# Helper function to get round up to next power of 10

# Calculations based on data sheet
min_current_lsb          = MAX_EXPECTED_AMPS / MAX_16BIT_REG                                     # minimum LSB for full range
current_lsb              = 1.0*10**math.ceil(math.log10(MAX_EXPECTED_AMPS / 2**15))              # p. 12 eq. 2 (with rounding up)
calibration_val          = int(CALIBRATION_SCALER_CONST / (current_lsb * SHUNT_RESISTOR_OHMS))   # p. 12 eq. 1
power_lsb                = 20 * current_lsb                                                      # p. 12 eq. 3


# //////////////////////// ----  Config    ---- ////////////////////////

config_val = (VoltageRange.RANGE_16V           << VoltageRange.BIT_FIELD   ) | \
             (Gain.DIV_1_40MV                  << Gain.BIT_FIELD           ) | \
             (BADCResolution.ADCRES_12BIT_128S << BADCResolution.BIT_FIELD ) | \
             (SADCResolution.ADCRES_12BIT_128S << SADCResolution.BIT_FIELD ) | \
             (Mode.SANDBVOLT_CONTINUOUS        << Mode.BIT_FIELD           )

# /////////////////////////////////////////////////////////////////////


# ////////////////////// ----  Helper Functions   ---- ////////////////

# Big Endian reading and writing

def registerReader(smbus, i2c_addr, register, length=2):
    data = smbus.read_i2c_block_data(i2c_addr, register, length)
    return (data[0] << 8) | data[1]

def registerWriter(smbus, i2c_addr, register, data):
    high_reg = (data >> 8) & 0b1111_1111
    low_reg = data & 0b1111_1111
    smbus.write_i2c_block_data(i2c_addr, register, [high_reg, low_reg])


# /////////////////////////////////////////////////////////////////////

bus = smbus.SMBus(I2C_BUS)
registerWriter(bus, INA219_ADDR, REG_CALIBRATION, calibration_val)
registerWriter(bus, INA219_ADDR, REG_CONFIG, config_val)

# Read Voltage Register
# Bit 0 is Math Overflow Flag
# Bit 1 is Conversion Ready
# Bit 2 is ignored
# Bits 3->15 is the voltage, with each less significant bit being 4 mv
# We skip the first 3 bits
voltReg = registerReader(bus, INA219_ADDR, REG_BUSVOLTAGE)
voltage = (voltReg >> 3) * 0.004

# Read shunt current (16-bit signed)
# Sign correction for current by checking MSB
currentReg          = registerReader(bus, INA219_ADDR, REG_CURRENT)
currentRegCorrected = currentReg if currentReg < 0x8000  else currentReg - 0x10000
current = currentRegCorrected * current_lsb

# Read power (16-bit unsigned)
powerReg = registerReader(bus, INA219_ADDR, REG_POWER)
power = powerReg * power_lsb                             # The power register is scaling of current * bus; convert to mW:

# Try to find battery percentage
ASSUMED_v_AT_100 = 8.4
ASSUMED_v_AT_0   = 6.0
percentage = max(min((voltage - ASSUMED_v_AT_0)/(ASSUMED_v_AT_100-ASSUMED_v_AT_0)*100, 100), 0)

# Print the readings
print(f"{voltage:.3f} {current*1000:.6f} {power*1000:.3f} {percentage:.1f}")
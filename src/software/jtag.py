import time
import jtag_uart
import sys
import random

from skimage.io import imread
from skimage.transform import resize

def writeAndCheck(ju, writearray):
    write(ju, writearray)
    check(ju, writearray)

def write(ju, writearray):
    writedata = bytes()
    index = 0
    while (index < len(writearray)):
        writedata = bytes()
        for i in range(0, 16 * 2**10):
            writedata += bytes([writearray[index]])
            index += 1
            if (index == len(writearray)):
                break
        ju.write(writedata)

def check(ju, writearray):
    with open("out.txt", "w"):
            pass
    while (len(ju.read())):
        time.sleep(0.1)
    print("-----Start Transfer-----")
    while (ju.bytes_available() == 0):
        pass
    readarray = []
    index = 0
    mismatchCount = 0
    while (ju.bytes_available() and index < len(writearray)):
        readarray = ju.read()
        with open("out.txt", "a") as f:
            for i in range(len(readarray)):
                f.write(f"""{i+index:x} : {readarray[i]:x}""")
                if (i+index >= len(writearray)):
                    break
                if (readarray[i] != writearray[i+index]):
                    f.write(f""" | MISMATCH: wrote {writearray[i+index]:x}""")
                    mismatchCount += 1
                f.write("\n")
        index += len(readarray)
        time.sleep(0.1)
    print(f"""Mismatches: {mismatchCount}""")

def checksum(ju):
    readarray = []
    writearray = []
    for i in range(0, 16 * 16 * 2**10):
        # num = i % 256
        num = random.randint(0, 256)
        writearray.append(num)
    writeAndCheck(ju, writearray)

def image_8bit():
    image_path = input("Path to input image (relative or absolute): ")
    image = imread(image_path).astype("uint8")
    x = 640
    y = 480
    image_resized = resize(image, (y, x), anti_aliasing=True, preserve_range=True).astype("uint8")
    ret = []
    for i in range(0, len(image_resized)):
        for j in range(0, len(image_resized[i])):
            ret.append(((image_resized[i][j][1]&0xF0)) | ((image_resized[i][j][2]&0xF0) >> 4))
            ret.append((image_resized[i][j][0]&0xF0) >> 4)
    return ret

def main():
    ju = jtag_uart.intel_jtag_uart()
    image = image_8bit()
    while True:
        c = input(">")
        if (c):
            if (c == "i"):
                image = image_8bit()
            writeAndCheck(ju, image)
        else:
            checksum(ju)

if (__name__ == "__main__"):
    main()
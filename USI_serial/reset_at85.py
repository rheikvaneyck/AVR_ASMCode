import RPi.GPIO as GPIO
from time import sleep

GPIO.setmode(GPIO.BCM)
PIN = 25
pinstate = False
GPIO.setup(PIN, GPIO.OUT)

GPIO.output(PIN, True)
sleep(0.1)
GPIO.output(PIN, False)

import click
import time
from gpiozero import LED

@click.command()
@click.option('--blink', is_flag=True, help="Blink the LED every 1 second.")
@click.option('--static', is_flag=True, help="Keep the LED on continuously.")
@click.option('--pin', default=23, help="GPIO pin number where the LED is connected.")
def control_led(blink, static, pin):
    """Control an LED with blinking or static mode using GPIOZero."""
    led = LED(pin)

    if blink:
        click.echo("Blinking LED every 1 second. Press Ctrl+C to stop.")
        try:
            while True:
                led.on()
                time.sleep(1)
                led.off()
                time.sleep(1)
        except KeyboardInterrupt:
            click.echo("\nStopping blinking mode.")
            led.off()
    elif static:
        click.echo("Turning LED on statically. Press Ctrl+C to stop.")
        led.on()
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            click.echo("\nTurning LED off.")
            led.off()
    else:
        click.echo("Please specify either --blink or --static.")

if __name__ == '__main__':
    control_led()

// refs
// https://docs.esp-rs.org/esp-idf-svc/esp_idf_svc/index.html
// https://github.com/IniterWorker/esp32-s3-touch-lcd-1-28/blob/master/src/main.rs#L142
// https://releases.slint.dev/1.1.1/docs/rust/slint/
// https://releases.slint.dev/1.1.1/docs/rust/slint/
// https://files.waveshare.com/wiki/ESP32-S3-Touch-LCD-1.28/ESP32-S3-Touch-LCD-1.28-Sch.pdf
extern crate alloc;

use esp_idf_svc::hal::delay::{Delay, FreeRtos};
use esp_idf_svc::hal::gpio::{OutputPin, PinDriver};
use esp_idf_svc::hal::i2c::I2cDriver;
use esp_idf_svc::hal::prelude::*;
use esp_idf_svc::hal::spi::config::{Config, DriverConfig, Mode, Phase, Polarity};
use esp_idf_svc::hal::spi::{SpiDeviceDriver, SpiDriver};
use gc9a01::{prelude::*, Gc9a01, SPIDisplayInterface}; // lcd screen
use slint::platform::software_renderer::Rgb565Pixel;

use crate::cst816s::CST816S;
use crate::draw_buffer::DrawBuffer;

pub struct EspPlatform {
    window: alloc::rc::Rc<slint::platform::software_renderer::MinimalSoftwareWindow>,
    timer: esp_idf_svc::timer::EspTimerService<esp_idf_svc::timer::Task>,
}

impl EspPlatform {
    const DISPLAY_WIDTH: usize = 240;
    const DISPLAY_HEIGHT: usize = 240;

    // Create a new instance of the platform
    // we initialize stuff here
    // panic if things go wrong
    pub fn new() -> std::boxed::Box<Self> {
        // Setup the window
        log::info!("Creating window");
        let window =
            slint::platform::software_renderer::MinimalSoftwareWindow::new(Default::default());

        window.set_size(slint::PhysicalSize::new(
            Self::DISPLAY_WIDTH as u32,
            Self::DISPLAY_HEIGHT as u32,
        ));

        std::boxed::Box::new(Self {
            window,
            // display_driver,
            timer: esp_idf_svc::timer::EspTimerService::new().unwrap(),
        })
    }
}

impl slint::platform::Platform for EspPlatform {
    fn create_window_adapter(
        &self,
    ) -> Result<alloc::rc::Rc<dyn slint::platform::WindowAdapter>, slint::PlatformError> {
        // Since on MCUs, there can be only one window, just return a clone of self.window.
        // We'll also use the same window in the event loop.
        Ok(self.window.clone())
    }
    fn duration_since_start(&self) -> core::time::Duration {
        self.timer.now()
    }

    // Spins an event loop and renders the visible windows.
    // TODO: handle errors
    fn run_event_loop(&self) -> Result<(), slint::PlatformError> {
        log::info!("init event loop");
        // borrow gpio
        let peripherals = Peripherals::take().unwrap();
        let pins = peripherals.pins;

        // lcd spi
        let lcd_sclk = pins.gpio10;
        let lcd_mosi = pins.gpio11;
        let lcd_miso = pins.gpio12; // not used
        let lcd_cs = pins.gpio9; // chip select
        let lcd_dc = pins.gpio8;
        let lcd_reset = pins.gpio14;
        let lcd_backlight = pins.gpio2;

        // touch/imu on i2c
        let i2c_sda = pins.gpio6;
        let i2c_scl = pins.gpio7;
        // imu
        // let _qmi8658_int1 = pins.gpio4;
        // let _qmi8658_int2 = pins.gpio3;
        let touch_int = pins.gpio5;
        let touch_reset = pins.gpio13;

        let spi_driver = SpiDriver::new(
            peripherals.spi2,
            lcd_sclk,
            lcd_mosi,
            Some(lcd_miso),           // miso , no input required for screen
            &DriverConfig::default(), // here you can add dma, not sure if I need this or not
        )
        .unwrap();

        // setup i2c
        let i2c = I2cDriver::new(
            peripherals.i2c0,
            i2c_sda,
            i2c_scl,
            &esp_idf_svc::hal::i2c::config::Config::default(),
        )
        .unwrap();

        let config = Config::new().baudrate(2.MHz().into()).data_mode(Mode {
            polarity: Polarity::IdleLow,
            phase: Phase::CaptureOnFirstTransition,
        });

        let spi_device = SpiDeviceDriver::new(spi_driver, Some(lcd_cs), &config).unwrap();

        let lcd_dc_output = PinDriver::output(lcd_dc.downgrade_output()).unwrap();
        let interface = SPIDisplayInterface::new(spi_device, lcd_dc_output);

        let mut display_driver = Box::new(Gc9a01::new(
            interface,
            DisplayResolution240x240,
            DisplayRotation::Rotate180, // usb port down
        ));

        let mut backlight_output = PinDriver::output(lcd_backlight).unwrap();
        backlight_output.set_high().unwrap(); // turn on backlight

        let mut reset_output = PinDriver::output(lcd_reset.downgrade_output()).unwrap();
        let mut delay = Delay::new_default();

        display_driver.clear_fit().unwrap();
        display_driver.reset(&mut reset_output, &mut delay).unwrap();
        display_driver.init(&mut delay).unwrap();

        log::info!("Display configured!");

        let mut display_buffer = vec![Rgb565Pixel(0x0); Self::DISPLAY_WIDTH].into_boxed_slice();
        let mut draw_buffer = DrawBuffer {
            display_driver,
            buffer: &mut display_buffer,
        };

        // setup touch
        let mut touch = CST816S::new(
            i2c,
            PinDriver::input(touch_int).unwrap(),
            PinDriver::output(touch_reset).unwrap(),
        );

        touch.setup(&mut delay).unwrap();
        // TODO: setup handler for touch events

        log::info!("Entering main loop");
        loop {
            slint::platform::update_timers_and_animations();

            self.window.draw_if_needed(|renderer| {
                renderer.render_by_line(&mut draw_buffer);
            });

            if self.window.has_active_animations() {
                continue;
            }
            FreeRtos::delay_ms(16);
        }
    }
}

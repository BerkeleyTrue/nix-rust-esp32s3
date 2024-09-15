// refs
// https://docs.esp-rs.org/esp-idf-svc/esp_idf_svc/index.html
// https://github.com/IniterWorker/esp32-s3-touch-lcd-1-28/blob/master/src/main.rs#L142
// https://releases.slint.dev/1.1.1/docs/rust/slint/
// https://releases.slint.dev/1.1.1/docs/rust/slint/
extern crate alloc;
// use std::option::Option;
use esp_idf_svc::hal::gpio::{AnyIOPin, AnyOutputPin, Output, OutputPin, PinDriver};
use esp_idf_svc::hal::prelude::*;
use esp_idf_svc::hal::spi::config::{Config, DriverConfig, Mode, Phase, Polarity};
use esp_idf_svc::hal::spi::{SpiDeviceDriver, SpiDriver};
// use esp_idf_svc::hal::sys::EspError;
use esp_idf_svc::hal::delay::Delay;
// use embedded_graphics_core::pixelcolor::raw::RawU16;
use gc9a01::{mode::BufferedGraphics, prelude::*, Gc9a01, SPIDisplayInterface}; // lcd screen
                                                                               // use slint::PlatformError;
use slint::platform::software_renderer::{LineBufferProvider, Rgb565Pixel};

type BoxedDisplayDriver<'a> = Box<
    Gc9a01<
        SPIInterface<SpiDeviceDriver<'a, SpiDriver<'a>>, PinDriver<'a, AnyOutputPin, Output>>,
        DisplayResolution240x240,
        BufferedGraphics<DisplayResolution240x240>,
    >,
>;

pub struct EspPlatform {
    // display_driver: BoxedDisplayDriver<'a>,
    window: alloc::rc::Rc<slint::platform::software_renderer::MinimalSoftwareWindow>,
    timer: esp_idf_svc::timer::EspTimerService<esp_idf_svc::timer::Task>,
}

impl EspPlatform {
    const DISPLAY_WIDTH: usize = 240;
    const DISPLAY_HEIGHT: usize = 240;
    const DRAW_BUFFER_SIZE: usize = Self::DISPLAY_WIDTH * Self::DISPLAY_HEIGHT;

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

struct DrawBuffer<'a> {
    display_driver: BoxedDisplayDriver<'a>,
    buffer: &'a mut [Rgb565Pixel],
}

impl LineBufferProvider for &mut DrawBuffer<'_> {
    type TargetPixel = Rgb565Pixel;

    fn process_line(
        &mut self,
        _line: usize,
        range: core::ops::Range<usize>,
        render_fn: impl FnOnce(&mut [Rgb565Pixel]),
    ) {
        log::info!("process_line");
        let buffer = &mut self.buffer[range.clone()];

        render_fn(buffer);

        self.display_driver
            .send_line(&buffer.iter().map(|&x| x.0.to_be()).collect::<Vec<u16>>())
            .unwrap();
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
    fn run_event_loop(&self) -> Result<(), slint::PlatformError> {
        log::info!("init event loop");
        // borrow gpio
        let peripherals = Peripherals::take().unwrap();
        let pins = peripherals.pins;

        // lcd spi
        let lcd_sclk = pins.gpio10;
        let lcd_mosi = pins.gpio11;
        let lcd_cs = pins.gpio9; // chip select
        let lcd_dc = pins.gpio8;
        let lcd_reset = pins.gpio14;
        // let lcd_backlight = pins.gpio2;
        // touch/imu on i2c
        // let i2c_sda = pins.gpio6;
        // let i2c_scl = pins.gpio7;
        // imu
        // let _qmi8658_int1 = pins.gpio4;
        // let _qmi8658_int2 = pins.gpio3;

        let spi_driver = SpiDriver::new(
            peripherals.spi2,
            lcd_sclk,
            lcd_mosi,
            None::<AnyIOPin>,         // miso , no input required for screen
            &DriverConfig::default(), // here you can add dma, not sure if I need this or not
        )
        .unwrap();

        let config = Config::new().baudrate(2.MHz().into()).data_mode(Mode {
            polarity: Polarity::IdleLow,
            phase: Phase::CaptureOnFirstTransition,
        });

        let spi_device = SpiDeviceDriver::new(spi_driver, Some(lcd_cs), &config).unwrap();

        let lcd_dc_output = PinDriver::output(lcd_dc.downgrade_output()).unwrap();
        let interface = SPIDisplayInterface::new(spi_device, lcd_dc_output);

        let mut display_driver: BoxedDisplayDriver = Box::new(
            Gc9a01::new(
                interface,
                DisplayResolution240x240,
                DisplayRotation::Rotate0,
            )
            .into_buffered_graphics(),
        );

        // let mut backlight_output = PinDriver::output(lcd_backlight.downgrade_output()).unwrap();
        let mut reset_output = PinDriver::output(lcd_reset.downgrade_output()).unwrap();
        let mut delay = Delay::new_default();

        display_driver.clear_fit().unwrap();
        display_driver.reset(&mut reset_output, &mut delay).unwrap();
        display_driver.init(&mut delay).unwrap();
        display_driver.flush().unwrap();

        log::info!("Display configured!");

        let mut draw_buffer = DrawBuffer {
            display_driver,
            buffer: &mut [Rgb565Pixel(0x0); Self::DRAW_BUFFER_SIZE],
        };

        loop {
            log::info!("looping");
            slint::platform::update_timers_and_animations();

            self.window.draw_if_needed(|renderer| {
                renderer.render_by_line(&mut draw_buffer);
            });

            if self.window.has_active_animations() {
                continue;
            }
        }
    }
}

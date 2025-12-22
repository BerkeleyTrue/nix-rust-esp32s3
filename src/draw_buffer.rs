use embedded_graphics::pixelcolor::raw::RawU16;
use embedded_graphics::pixelcolor::Rgb565;
use embedded_graphics::prelude::{DrawTarget, Point, Size};
use embedded_graphics::primitives::Rectangle;
use slint::platform::software_renderer::{LineBufferProvider, Rgb565Pixel};

pub struct DrawBuffer<'a, D>
where
    D: DrawTarget<Color = Rgb565>,
{
    pub display_driver: Box<D>,
    pub buffer: &'a mut [Rgb565Pixel],
}

impl<T: DrawTarget<Color = Rgb565>> LineBufferProvider for &mut DrawBuffer<'_, T> {
    type TargetPixel = Rgb565Pixel;

    fn process_line(
        &mut self,
        line: usize,
        range: core::ops::Range<usize>,
        render_fn: impl FnOnce(&mut [Rgb565Pixel]),
    ) {
        let buffer = &mut self.buffer[range.clone()];

        // render into the line
        render_fn(buffer);

        // send the line to the display using draw target fill contiguous
        self.display_driver
            .fill_contiguous(
                &Rectangle::new(
                    Point::new(range.start as _, line as _),
                    Size::new(range.len() as _, 1),
                ),
                self.buffer[range.clone()]
                    .iter()
                    .map(|p| RawU16::new(p.0).into()),
            )
            .map_err(drop)
            .unwrap();
    }
}

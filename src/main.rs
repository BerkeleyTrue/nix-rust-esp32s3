// Prevent console window in addition to Slint window in Windows release builds when, e.g., starting the app via file manager. Ignored on other platforms.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]
mod esp32;
// use esp_idf as _;

slint::include_modules!();

fn main() -> Result<(), slint::PlatformError> {
    log::info!("Starting app");
    // It is necessary to call this function once. Otherwise some patches to the runtime
    // implemented by esp-idf-sys might not link properly. See https://github.com/esp-rs/esp-idf-template/issues/71
    esp_idf_svc::sys::link_patches();

    // Bind the log crate to the ESP Logging facilities
    esp_idf_svc::log::EspLogger::initialize_default();

    // slint: set platform
    log::info!("Setting platform");
    slint::platform::set_platform(esp32::EspPlatform::new()).unwrap();

    log::info!("Loading UI");
    let ui = AppWindow::new().expect("Failed to load UI");

    // ui.on_request_increase_value({
    //     let ui_handle = ui.as_weak();
    //     move || {
    //         let ui = ui_handle.unwrap();
    //         ui.set_counter(ui.get_counter() + 1);
    //     }
    // });
    //
    log::info!("Running UI");
    ui.run()
        .inspect_err(|e| log::error!("Error running UI: {:?}", e))
}

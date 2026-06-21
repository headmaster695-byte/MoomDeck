return {
    version = "1.0.0",
    title = "MoomDeck",
    data_file = "moomdeck/data.json",
    poll_interval = 0.5,
    sample_window = 120,
    min_sample_age = 2,
    ui_refresh = 0.2,
    categories = {
        item = { label = "Items", unit = "items", color = colors.lime },
        fluid = { label = "Fluids", unit = "mB", color = colors.lightBlue },
        energy = { label = "FE", unit = "FE", color = colors.yellow },
        stress = { label = "Stress", unit = "SU", color = colors.magenta },
    },
}

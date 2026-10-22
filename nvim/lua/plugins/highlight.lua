return {
    {
        "tzachar/local-highlight.nvim",
        enabled = true,
        opts = {
            disable_file_types = { 'tex' },
            hlgroup = 'IncSearch',
            cw_hlgroup = 'CurSearch',
            insert_mode = true,
            min_match_len = 3,
            max_match_len = 64,
            animate = {
                enabled = false,
                easing = "linear",
                duration = {
                    step = 10, -- ms per step
                    total = 100, -- maximum duration
                },
            },
        },
    },
    -- highlight words <leader>k
    {
        "Mr-LLLLL/interestingwords.nvim",
        main = "interestingwords",
        opts = {
            colors = { '#eeee55', '#ff5555', '#5555ff', '#66ff66', '#ff66ff', '#27F5F5', },
        },
    },
}

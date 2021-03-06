local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local thelpers = require('test.functional.terminal.helpers')
local feed, clear, nvim = helpers.feed, helpers.clear, helpers.nvim
local nvim_dir, execute = helpers.nvim_dir, helpers.execute
local eq, eval = helpers.eq, helpers.eval


describe('terminal window highlighting', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(50, 7)
    screen:set_default_attr_ids({
      [1] = {foreground = 45},
      [2] = {background = 46},
      [3] = {foreground = 45, background = 46},
      [4] = {bold = true, italic = true, underline = true}
    })
    screen:set_default_attr_ignore({
      [1] = {bold = true},
      [2] = {foreground = 12},
      [3] = {bold = true, reverse = true},
      [5] = {background = 11},
      [6] = {foreground = 130},
      [7] = {reverse = true},
      [8] = {background = 11},
    })
    screen:attach(false)
    execute('enew | call termopen(["'..nvim_dir..'/tty-test"]) | startinsert')
    screen:expect([[
      tty ready                                         |
                                                        |
                                                        |
                                                        |
                                                        |
                                                        |
      -- TERMINAL --                                    |
    ]])
  end)

  local function descr(title, attr_num, set_attrs_fn)
    local function sub(s)
      return s:gsub('NUM', attr_num)
    end

    describe(title, function() 
      before_each(function()
        set_attrs_fn()
        thelpers.feed_data('text')
        thelpers.clear_attrs()
        thelpers.feed_data('text')
      end)

      local function pass_attrs()
        local s = sub([[
          tty ready                                         |
          {NUM:text}text                                          |
                                                            |
                                                            |
                                                            |
                                                            |
          -- TERMINAL --                                    |
        ]])
        screen:expect(s)
      end

      it('will pass the corresponding attributes', pass_attrs)

      it('will pass the corresponding attributes on scrollback', function()
        pass_attrs()
        local lines = {}
        for i = 1, 8 do
          table.insert(lines, 'line'..tostring(i))
        end
        table.insert(lines, '')
        thelpers.feed_data(lines)
        screen:expect([[
          line4                                             |
          line5                                             |
          line6                                             |
          line7                                             |
          line8                                             |
                                                            |
          -- TERMINAL --                                    |
        ]])
        feed('<c-\\><c-n>gg')
        local s = sub([[
          ^tty ready                                         |
          {NUM:text}textline1                                     |
          line2                                             |
          line3                                             |
          line4                                             |
          line5                                             |
                                                            |
        ]])
        screen:expect(s)
      end)
    end)
  end

  descr('foreground', 1, function() thelpers.set_fg(45) end)
  descr('background', 2, function() thelpers.set_bg(46) end)
  descr('foreground and background', 3, function()
    thelpers.set_fg(45)
    thelpers.set_bg(46)
  end)
  descr('bold, italics and underline', 4, function()
    thelpers.set_bold()
    thelpers.set_italic()
    thelpers.set_underline()
  end)
end)


describe('terminal window highlighting with custom palette', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(50, 7)
    screen:set_default_attr_ids({
      [1] = {foreground = 1193046, special = Screen.colors.Black}
    })
    screen:set_default_attr_ignore({
      [1] = {bold = true},
      [2] = {foreground = 12},
      [3] = {bold = true, reverse = true},
      [5] = {background = 11},
      [6] = {foreground = 130},
      [7] = {reverse = true},
      [8] = {background = 11},
    })
    screen:attach(true)
    nvim('set_var', 'terminal_color_3', '#123456')
    execute('enew | call termopen(["'..nvim_dir..'/tty-test"]) | startinsert')
    screen:expect([[
      tty ready                                         |
                                                        |
                                                        |
                                                        |
                                                        |
                                                        |
      -- TERMINAL --                                    |
    ]])
  end)

  it('will use the custom color', function()
    thelpers.set_fg(3)
    thelpers.feed_data('text')
    thelpers.clear_attrs()
    thelpers.feed_data('text')
    screen:expect([[
      tty ready                                         |
      {1:text}text                                          |
                                                        |
                                                        |
                                                        |
                                                        |
      -- TERMINAL --                                    |
    ]])
  end)
end)

describe('synIDattr()', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(50, 7)
    execute('highlight Normal ctermfg=252 guifg=#ff0000 guibg=Black')
    -- Salmon #fa8072 Maroon #800000
    execute('highlight Keyword ctermfg=79 guifg=Salmon guisp=Maroon')
  end)

  it('returns cterm-color if RGB-capable UI is _not_ attached', function()
    eq('252', eval('synIDattr(hlID("Normal"),  "fg")'))
    eq('252', eval('synIDattr(hlID("Normal"),  "fg#")'))
    eq('-1',  eval('synIDattr(hlID("Normal"),  "bg")'))
    eq('-1',  eval('synIDattr(hlID("Normal"),  "bg#")'))
    eq('79',  eval('synIDattr(hlID("Keyword"), "fg")'))
    eq('79',  eval('synIDattr(hlID("Keyword"), "fg#")'))
    eq('',    eval('synIDattr(hlID("Keyword"), "sp")'))
    eq('',    eval('synIDattr(hlID("Keyword"), "sp#")'))
  end)

  it('returns gui-color if "gui" arg is passed', function()
    eq('Black',  eval('synIDattr(hlID("Normal"),  "bg", "gui")'))
    eq('Maroon', eval('synIDattr(hlID("Keyword"), "sp", "gui")'))
  end)

  it('returns gui-color if RGB-capable UI is attached', function()
    screen:attach(true)
    eq('#ff0000', eval('synIDattr(hlID("Normal"),  "fg")'))
    eq('Black',   eval('synIDattr(hlID("Normal"),  "bg")'))
    eq('Salmon',  eval('synIDattr(hlID("Keyword"), "fg")'))
    eq('Maroon',  eval('synIDattr(hlID("Keyword"), "sp")'))
  end)

  it('returns #RRGGBB value for fg#/bg#/sp#', function()
    screen:attach(true)
    eq('#ff0000', eval('synIDattr(hlID("Normal"), "fg#")'))
    eq('#000000', eval('synIDattr(hlID("Normal"), "bg#")'))
    eq('#fa8072', eval('synIDattr(hlID("Keyword"), "fg#")'))
    eq('#800000', eval('synIDattr(hlID("Keyword"), "sp#")'))
  end)

  it('returns color number if non-GUI', function()
    screen:attach(false)
    eq('252', eval('synIDattr(hlID("Normal"), "fg")'))
    eq('79', eval('synIDattr(hlID("Keyword"), "fg")'))
  end)
end)

###
Chosen for Protoype.js
by Patrick Filler for Harvest

Copyright (c) 2011 Harvest

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
###

root = exports ? this
$ = jQuery

$.fn.extend({
  chosen: (data, options) ->
    $(this).each((input_field) -> 
      new Chosen(this, data, options)
    )
})

class Chosen

  constructor: (elmn) ->
    this.set_default_values()
    
    @form_field = elmn
    @is_multiple = @form_field.multiple

    @default_text_default = if @form_field.multiple then "Select Some Options" else "Select an Option"

    this.set_up_html()
    this.register_observers()


  set_default_values: ->
    
    @click_test_action = (evt) => this.test_active_click(evt)
    @active_field = false
    @mouse_on_container = false
    @results_showing = false
    @result_highlighted = null
    @result_single_selected = null
    @choices = 0

  set_up_html: ->
    @container_id = @form_field.id + "_chzn"
    
    @f_width = ($ @form_field).width()
    
    @default_text = if ($ @form_field).attr 'title' then ($ @form_field).attr 'title' else @default_text_default
    
    container_div = ($ "<div />", {
      id: @container_id
      class: 'chzn-container'
      style: 'width: ' + (@f_width) + 'px;' #use parens around @f_width so coffeescript doesn't think + ' px' is a function parameter
    })
    
    if @is_multiple
      container_div.html '<ul class="chzn-choices"><li class="search-field"><input type="text" value="' + @default_text + '" class="default" style="width:25px;" /></li></ul><div class="chzn-drop" style="left:-9000px;"><ul class="chzn-results"></ul></div>'
    else
      container_div.html '<a href="#" class="chzn-single"><span>' + @default_text + '</span><div><b></b></div></a><div class="chzn-drop" style="left:-9000px;"><div class="chzn-search"><input type="text" /></div><ul class="chzn-results"></ul></div>';

    ($ @form_field).hide().after container_div
    @container = ($ '#' + @container_id)
    @container.addClass( "chzn-container-" + (if @is_multiple then "multi" else "single") )
    @dropdown = @container.find('div.chzn-drop').first()
    
    dd_top = @container.height()
    dd_width = (@f_width - get_side_border_padding(@dropdown))
    
    @dropdown.css({"width": dd_width  + "px", "top": dd_top + "px"})

    @search_field = @container.find('input').first()
    @search_results = @container.find('ul.chzn-results').first()
    this.search_field_scale()

    @search_no_results = @container.find('li.no-results').first()
    
    if @is_multiple
      @search_choices = @container.find('ul.chzn-choices').first()
      @search_container = @container.find('li.search-field').first()
    else
      @search_container = @container.find('div.chzn-search').first()
      @selected_item = @container.find('.chzn-single').first()
      sf_width = dd_width - get_side_border_padding(@search_container) - get_side_border_padding(@search_field)
      @search_field.css( {"width" : sf_width + "px"} )
    
    this.results_build()
    this.set_tab_index()


  register_observers: ->
    @container.click (evt) => this.container_click(evt)
    @container.mouseenter (evt) => this.mouse_enter(evt)
    @container.mouseleave (evt) => this.mouse_leave(evt)
  
    @search_results.click (evt) => this.search_results_click(evt)
    @search_results.mouseover (evt) => this.search_results_mouseover(evt)
    @search_results.mouseout (evt) => this.search_results_mouseout(evt)

    ($ @form_field).bind "liszt:updated", (evt) => this.results_update_field(evt)

    @search_field.blur (evt) => this.input_blur(evt)
    @search_field.keyup (evt) => this.keyup_checker(evt)
    @search_field.keydown (evt) => this.keydown_checker(evt)

    if @is_multiple
      @search_choices.click (evt) => this.choices_click(evt)
      @search_field.focus (evt) => this.input_focus(evt)
    else
      @selected_item.focus (evt) => this.activate_field(evt)

  container_click: (evt) ->
    if evt and evt.type is "click"
      evt.stopPropagation()
    if not @pending_destroy_click
      if not @active_field
        @search_field.val "" if @is_multiple
        $(document).click @click_test_action
        this.results_show()
      else if not @is_multiple and evt and ($(evt.target) is @selected_item || $(evt.target).parents("a.chzn-single").length)
        this.results_show()

      this.activate_field()
    else
      @pending_destroy_click = false

  mouse_enter: -> @mouse_on_container = true
  mouse_leave: -> @mouse_on_container = false

  input_focus: (evt) ->
    setTimeout this.container_click.bind(this), 50 unless @active_field
  
  input_blur: (evt) ->
    if not @mouse_on_container
      @active_field = false
      setTimeout this.blur_test.bind(this), 100

  blur_test: (evt) ->
    this.close_field() if not @active_field and @container.hasClass "chzn-container-active"

  close_field: ->
    $(document).unbind "click", @click_test_action
    
    if not @is_multiple
      @selected_item.attr "tabindex", @search_field.attr("tabindex")
      @search_field.attr "tabindex", -1
    
    @active_field = false
    this.results_hide()

    @container.removeClass "chzn-container-active"
    this.winnow_results_clear()
    this.clear_backstroke()

    this.show_search_field_default()
    this.search_field_scale()

  activate_field: ->
    if not @is_multiple and not @active_field
      @search_field.attr "tabindex", (@selected_item.attr "tabindex")
      @selected_item.attr "tabindex", -1

    @container.addClass "chzn-container-active"
    @active_field = true

    @search_field.val(@search_field.val())
    @search_field.focus()


  test_active_click: (evt) ->
    if $(evt.target).parents('#' + @container.id).length
      @active_field = true
    else
      this.close_field()
    
  results_build: ->
    startTime = new Date()
    @parsing = true
    @results_data = OptionsParser.select_to_array @form_field

    if @is_multiple and @choices > 0
      @search_choices.find("li.search-choice").remove()
      @choices = 0
    else if not @is_multiple
      @selected_item.find("span").text @default_text

    content = ''
    for data in @results_data
      if data.group
        content += this.result_add_group data
      else
        content += this.result_add_option data
        if data.selected and @is_multiple
          this.choice_build data
        else if data.selected and not @is_multiple
          @selected_item.find("span").text data.text

    this.show_search_field_default()
    @search_results.html content
    @parsing = false


  result_add_group: (group) ->
    if not group.disabled
      group.dom_id = @form_field.id + "chzn_g_" + group.id
      '<li id="' + group.dom_id + '" class="group-result">' + $("<div />").text(group.label).html() + '</li>'
    else
      ""
  
  result_add_option: (option) ->
    if not option.disabled 
      option.dom_id = @form_field.id + "chzn_o_" + option.id
      
      classes = if option.selected and @is_multiple then [] else ["active-result"]
      classes.push "result-selected" if option.selected
      classes.push "group-option" if option.group_id >= 0
      
      '<li id="' + option.dom_id + '" class="' + classes.join(' ') + '">' + $("<div />").text(option.text).html() + '</li>'
    else
      ""

  results_update_field: ->
    this.result_clear_highlight()
    @result_single_selected = null
    this.results_build()

  result_do_highlight: (el) ->
    if el.length
      this.result_clear_highlight();

      @result_highlight = el;
      @result_highlight.addClass "highlighted"

      maxHeight = parseInt @search_results.css("maxHeight"), 10
      visible_top = @search_results.scrollTop()
      visible_bottom = maxHeight + visible_top
    
      high_top = @result_highlight.position().top
      high_bottom = high_top + @result_highlight.outerHeight()
    
      #console.log visible_top, visible_bottom, high_top, high_bottom

      if high_bottom >= visible_bottom
        #console.log "bottom is greater than bottom"
        @search_results.scrollTop if (high_bottom - maxHeight) > 0 then (high_bottom - maxHeight) else 0
      else if high_top < visible_top
        #console.log "top is less than top"
        @search_results.scrollTop high_top
    
  result_clear_highlight: ->
    @result_highlight.removeClass "highlighted" if @result_highlight
    @result_highlight = null

  results_show: ->
    if not @is_multiple
      @selected_item.addClass "chzn-single-with-drop"
      if @result_single_selected
        this.result_do_highlight( @result_single_selected )

    dd_top = if @is_multiple then @container.height() else (@container.height() - 1)
    @dropdown.css {"top":  dd_top + "px", "left":0}
    @results_showing = true

    @search_field.focus()
    @search_field.val @search_field.val()

    this.winnow_results()

  results_hide: ->
    @selected_item.removeClass "chzn-single-with-drop" unless @is_multiple
    this.result_clear_highlight()
    @dropdown.css {"left":"-9000px"}
    @results_showing = false


  set_tab_index: (el) ->
    if ($ @form_field).attr "tabindex"
      ti = ($ @form_field).attr "tabindex"
      ($ @form_field).attr "tabindex", -1

      if @is_multiple
        @search_field.attr "tabindex", ti
      else
        @selected_item.attr "tabindex", ti
        @search_field.attr "tabindex", -1

  show_search_field_default: ->
    if @is_multiple and @choices < 1 and not @active_field
      @search_field.val(@default_text)
      @search_field.addClass "default"
    else
      @search_field.val("")
      @search_field.removeClass "default"

  search_results_click: (evt) ->
    target = if $(evt.target).hasClass "active-result" then $(evt.target) else $(evt.target).parents(".active-result").first()
    if target
      # TODO fix
      @result_highlight = target
      this.result_select()

  search_results_mouseover: (evt) ->
    target = if $(evt.target).hasClass "active-result" then $(evt.target) else $(evt.target).parents(".active-result").first()
    this.result_do_highlight( target ) if target

  search_results_mouseout: (evt) ->
    this.result_clear_highlight() if $(evt.target).hasClass "active-result" or $(evt.target).parents('.active-result').first()


  choices_click: (evt) ->
    evt.preventDefault()
    if( @active_field and not($(evt.target).hasClass "search-choice" or $(evt.target).parents('.search-choice').first) and not @results_showing )
      this.results_show()

  choice_build: (item) ->
    choice_id = @form_field.id + "_chzn_c_" + item.id
    @choices += 1
    @search_container.before  '<li class="search-choice" id="' + choice_id + '"><span>' + item.text + '</span><a href="#" class="search-choice-close" rel="' + item.id + '"></a></li>'
    link = $('#' + choice_id).find("a").first()
    link.click (evt) => this.choice_destroy_link_click(evt)

  choice_destroy_link_click: (evt) ->
    evt.preventDefault()
    @pending_destroy_click = true
    this.choice_destroy $(evt.target)

  choice_destroy: (link) ->
    @choices -= 1
    this.show_search_field_default()

    this.results_hide() if @is_multiple and @choices > 0 and @search_field.val().length < 1

    this.result_deselect (link.attr "rel")
    link.parents('li').first().remove()

  result_select: ->
    if @result_highlight
      high = @result_highlight
      high_id = high.attr "id"
      
      this.result_clear_highlight();

      high.addClass "result-selected"
      
      if @is_multiple 
        this.result_deactivate high
      else
        @result_single_selected = high
      
      position = high_id.substr(high_id.lastIndexOf("_") + 1 )
      item = @results_data[position]
      item.selected = true

      @form_field.options[item.select_index].selected = true

      if @is_multiple
        this.choice_build item
      else
        @selected_item.find("span").first().text item.text

      this.results_hide()
      @search_field.val ""

      # TODO
      #@form_field.simulate("change") if typeof Event.simulate is 'function'
      this.search_field_scale()

  result_activate: (el) ->
    el.addClass("active-result").show()

  result_deactivate: (el) ->
    el.removeClass("active-result").hide()

  result_deselect: (pos) ->
    result_data = @results_data[pos]
    result_data.selected = false

    @form_field.options[result_data.select_index].selected = false
    result = $(@form_field.id + "chzn_o_" + pos)
    result.removeClass("result-selected").addClass("active-result").show()

    this.result_clear_highlight()
    this.winnow_results()

    @form_field.simulate("change") if typeof Event.simulate is 'function'
    this.search_field_scale()

  results_search: (evt) ->
    if @results_showing
      this.winnow_results()
    else
      this.results_show()

  winnow_results: ->
    startTime = new Date()
    this.no_results_clear()
    
    results = 0

    searchText = if @search_field.val() is @default_text then "" else $.trim @search_field.val()
    regex = new RegExp('^' + searchText.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&"), 'i')
    zregex = new RegExp(searchText.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&"), 'i')

    for option in @results_data
      if not option.disabled
        if option.group
          $(option.dom_id).hide()
        else if not (@is_multiple and option.selected)
          found = false
          result_id = @form_field.id + "chzn_o_" + option.id
          
          if regex.test option.text
            found = true;
            results += 1;
          else if option.text.indexOf(" ") >= 0 or option.text.indexOf("[") == 0
            #TODO: replace this substitution of /\[\]/ with a list of characters to skip.
            parts = option.text.replace(/\[|\]/g, "").split(" ")
            if parts.length
              for part in parts
                if regex.test part
                  found = true
                  results += 1

          if found
            if searchText.length
              startpos = option.text.search zregex
              text = option.text.substr(0, startpos + searchText.length) + '</em>' + option.text.substr(startpos + searchText.length)
              text = text.substr(0, startpos) + '<em>' + text.substr(startpos)
            else
              text = option.text

            $("#" + result_id).html text if $("#" + result_id).html != text

            this.result_activate $("#" + result_id)

            $("#" + @results_data[option.group_id].dom_id).show() if option.group_id?
          else
            this.result_clear_highlight() if @result_highlight and result_id is @result_highlight.attr 'id'
            this.result_deactivate $("#" + result_id)
    
    if results < 1 and searchText.length
      this.no_results searchText
    else
      this.winnow_results_set_highlight()

  winnow_results_clear: ->
    @search_field.val ""
    lis = @search_results.find("li")

    for li in lis
      li = $(li)
      if li.hasClass "group-result"
        li.show()
      else if not @is_multiple or not li.hasClass "result-selected"
        this.result_activate li

  winnow_results_set_highlight: ->
    if not @result_highlight
      do_high = @search_results.find(".active-result").first()
      if(do_high)
        this.result_do_highlight do_high
  
  no_results: (terms) ->
    no_results_html = $('<li class="no-results">No results match "<span></span>"</li>')
    no_results_html.find("span").first().text(terms)

    @search_results.append no_results_html
  
  no_results_clear: ->
    @search_results.find(".no-results").remove()

  keydown_arrow: ->
    if not @result_highlight
      first_active = @search_results.find("li.active-result").first()
      this.result_do_highlight $(first_active) if first_active
    else if @results_showing
      next_sib = @result_highlight.nextAll("li.active-result").first()
      this.result_do_highlight next_sib if next_sib
    this.results_show() if not @results_showing

  keyup_arrow: ->
    if not @results_showing and not @is_multiple
      this.results_show() 
    else if @result_highlight
      prev_sibs = @result_highlight.prevAll("li.active-result")
      
      if prev_sibs.length
        this.result_do_highlight prev_sibs.first()
      else
        this.results_hide() if @choices > 0
        this.result_clear_highlight()

  keydown_backstroke: ->
    if @pending_backstroke
      this.choice_destroy @pending_backstroke.find("a").first()
      this.clear_backstroke()
    else
      @pending_backstroke = @search_container.siblings("li.search-choice").last()
      @pending_backstroke.addClass "search-choice-focus"

  clear_backstroke: ->
    @pending_backstroke.removeClass "search-choice-focus" if @pending_backstroke
    @pending_backstroke = null

  keyup_checker: (evt) ->
    stroke = evt.which ? evt.keyCode
    this.search_field_scale()

    switch stroke
      when 8
        if @is_multiple and @backstroke_length < 1 and @choices > 0
          this.keydown_backstroke()
        else if not @pending_backstroke
          this.result_clear_highlight()
          this.results_search()
      when 13
        evt.preventDefault()
        this.result_select() if this.results_showing
      when 9, 13, 38, 40, 16
        # don't do anything on these keys
      else this.results_search()


  keydown_checker: (evt) ->
    stroke = evt.which ? evt.keyCode
    this.search_field_scale()

    this.clear_backstroke() if stroke != 8 and this.pending_backstroke
    
    switch stroke
      when 8
        @backstroke_length = this.search_field.val().length
        break
      when 9
        @mouse_on_container = false
        break
      when 13
        evt.preventDefault()
        break
      when 38
        evt.preventDefault()
        this.keyup_arrow()
        break
      when 40
        this.keydown_arrow()
        break


  search_field_scale: ->
    if @is_multiple
      h = 0
      w = 0

      style_block = "position:absolute; left: -1000px; top: -1000px; display:none;"
      styles = ['font-size','font-style', 'font-weight', 'font-family','line-height', 'text-transform', 'letter-spacing']
      
      for style in styles
        style_block += style + ":" + @search_field.css(style) + ";"
      
      div = $('<div />', { 'style' : style_block }).text @search_field.val()
      $('body').append div

      w = div.width() + 25
      div.remove()

      if( w > @f_width-10 )
        w = @f_width - 10

      @search_field.css({'width': w + 'px'})

      dd_top = @container.height()
      @dropdown.css({"top":  dd_top + "px"})

get_side_border_padding = (elmt) ->
  side_border_padding = elmt.outerWidth() - elmt.width()

root.get_side_border_padding = get_side_border_padding

class OptionsParser
  
  constructor: ->
    @group_index = 0
    @sel_index = 0
    @parsed = []

  add_node: (child) ->
    if child.nodeName is "OPTGROUP"
      this.add_group child
    else
      this.add_option child

  add_group: (group) ->
    group_id = @sel_index + @group_index
    @parsed.push
      id: group_id
      group: true
      label: group.label
      position: @group_index
      children: 0
      disabled: group.disabled
    this.add_option( option, group_id, group.disabled ) for option in group.childNodes
    @group_index += 1

  add_option: (option, group_id, group_disabled) ->
    if option.nodeName is "OPTION" and (@sel_index > 0 or option.text != "")
      if group_id || group_id is 0
        @parsed[group_id].children += 1
      @parsed.push
        id: @sel_index + @group_index
        select_index: @sel_index
        value: option.value
        text: option.text
        selected: option.selected
        disabled: ((group_disabled is true) ? group_disabled : option.disabled)
        group_id: group_id
      @sel_index += 1

OptionsParser.select_to_array = (select) ->
  parser = new OptionsParser()
  parser.add_node( child ) for child in select.childNodes
  parser.parsed
  
root.OptionsParser = OptionsParser
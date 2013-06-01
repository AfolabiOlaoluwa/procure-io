$ = jQuery

$.fn.extend
  resizableColumns: (method) ->
    makeResizable = ($table) ->
      tableId = $table.data('resizable-columns-id')

      setColumnWidth = ($thisColumn, newWidth) ->
        columnId = tableId + "-" + $thisColumn.data('resizable-column-id')

        $thisColumn.css
          width: newWidth

        store.set(columnId, newWidth)

      resetHandles = ->
        $(".rc-draghandle").css
          left: ''
          height: ''

      setSizes = (difference, pos) ->
        $thisColumn = $table.find("tr:first th").eq(pos)
        $nextColumn = $table.find("tr:first th").eq(pos + 1)
        currentWidth = $thisColumn.width()
        newWidth = currentWidth + difference

        setColumnWidth($thisColumn, newWidth)

        couldntResize = newWidth - $thisColumn.width()

        if $nextColumn.length > 0
          newNextColumnWidth = $nextColumn.width() - couldntResize
          setColumnWidth($nextColumn, newNextColumnWidth)

        resetHandles()

      i = 0
      $table.find("tr:first th").each ->
        index = i

        columnId = tableId + "-" + $(@).data('resizable-column-id')

        $(@).css
          position: "relative"
          width: store.get(columnId)

        $dragHandle = $("<div class='rc-draghandle'></div>")

        $(@).append $dragHandle

        initialPos = undefined

        $dragHandle.draggable
          axis: "x"
          start: ->
            initialPos = $(@).offset().left
            $(@).addClass('dragging')
            $(@).height($table.height())
          stop: (e, ui) ->
            $(@).removeClass('dragging')
            difference = $(@).offset().left - initialPos
            setSizes(difference, index)

        i = i + 1

    $(@).each ->
      if method == 'destroy'
        $(@).find(".rc-draghandle").remove()
        $(@).find("th").css
          position: ''
          width: ''

      else
        makeResizable $(@)
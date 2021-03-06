class app.views.SearchForm extends Backbone.View
  el: '#top-form'

  events:
    'keyup #search-add-field': 'search'

  initialize: ->
    @$query = $ '#search-add-field'
    @$searchAddIcon = @$ "label[for=search-add-field] i"

  render: ->
    @$query.attr 'placeholder', 'Search contact'
    @$searchAddIcon.removeAttr('class').addClass("icon-search")
    @$el.removeClass 'add-form-state'
    @$('.has-error').removeClass 'has-error'
    app.mainPage.closeError()
    @$query.val("").focus()
    @$(".second-row").slideUp('fast')

  search: ->
    opened = @$(".second-row:visible").length is 0
    if opened
      app.mainPage.filter @$query.val()

class app.views.AddForm extends Backbone.View
  el: '#top-form'

  events:
    'click button.cancel': 'clear'
    'click button.save': 'save'
    'keyup input': 'clearErorrs'

  initialize: ->
    _.bindAll @, 'renderGroups', 'resetModel'
    @$name = $ '#search-add-field'
    @$phone = $ '#phone-field'
    @$group = $ '#group-field'
    @$searchAddIcon = @$ "label[for=search-add-field] i"
    app.models.contacts.on 'reset', @resetModel
    app.models.groups.on 'all', @renderGroups

  renderGroups: ->
    @$group.html app.models.groups.makeOptions()

  resetModel: ->
    @clear()
    @model = new app.models.Contact()
    app.models.contacts.add @model
    @model.on 'invalid', ((a,b) =>
      [fields, message] = @model.validationError
      for field in fields
        @$("[data-field=#{field}]").parent().addClass('has-error')
      app.mainPage.showError message
    ), this

  clear: ->
    @$name.val ""
    @$phone.val ""

  clearErorrs: (e) ->
    ($ e.target).parents('.has-error').removeClass 'has-error'
    app.mainPage.closeError()

  save: ->
    @model.save {
      name: @$name.val()
      phone: @$phone.val()
      groupId: @$group.val()
    }, {
      success: =>
        @model.off null, null, this
        @trigger 'done'
        @resetModel()
    }

  render: ->
    @$name.attr 'placeholder', 'Full name'
    @$searchAddIcon.removeAttr('class').addClass 'icon-user'
    @$el.addClass 'add-form-state'
    @$('.has-error').removeClass 'has-error'
    app.mainPage.closeError()
    @$name.focus()
    @renderGroups()
    @$(".second-row").slideDown('fast')

    @$group.selectpicker(
      container: 'body'
    ).selectpicker('setStyle', 'form-control btn-lg input-lg group-select-ui')


class app.views.ContactsListView extends Backbone.View
  el: '#contacts-list'

  events:
    'click .row .col': 'editMode'
    'click .row .edit': 'editMode'
    'click .row .save': 'saveRow'
    'click .row .cancel': 'cancelRow'
    'click .row .delete': 'clickDelete'
    'keyup .row input': 'keyPress'

  collection: app.models.contacts

  template: _.template $("#contact-list-item").html()

  initialize: ->
    _.bindAll @, 'renderAll', 'renderOne', 'deleteOne', 'changeOne'
    @collection.on 'reset add', @renderAll
    @collection.on 'destroy', @deleteOne
    @collection.on 'change', @changeOne
    @collection.fetch reset: true

  deleteOne: (contact) ->
    $row = $("#contact-#{contact.id}")
    $row.slideUp('fast')
    setTimeout (-> $row.remove()), 1000

  changeOne: (contact) ->
    $row = $("#contact-#{contact.id}")
    if $row.length
      $row.replaceWith @renderOne contact
      @updateSelects()
    else
      @renderAll()

  getRow: (e) -> ($ e.currentTarget).parents('.row:eq(0)')

  getContactOnEvent: (e) ->
    $row = @getRow e
    id = $row.data 'id'
    @collection.get id

  keyPress: (e) ->
    if e.keyCode is 13
      @saveRow(e)

  editMode: (e) ->
    $row = @getRow e
    return if $row.is '.edit-mode'
    @cancelAllRows()
    $row.addClass 'edit-mode'
    ($ e.currentTarget).closest('.col').find("input, button.dropdown-toggle").focus().select()

  cancelAllRows: ->
    $(".row").removeClass 'edit-mode'

  cancelRow: (e) ->
    $row = @getRow e
    $row.removeClass 'edit-mode'

  clickDelete: (e) ->
    @getContactOnEvent(e).destroy()

  saveRow: (e) ->
    $row = @getRow e
    contact = @getContactOnEvent e
    contact.save
      name: $row.find(".js-name input").val()
      phone: $row.find(".js-phone input").val()
      groupId: $row.find(".js-group select").val()

  renderOne: (contact) ->
    return if contact.isNew()
    attrs = _.clone contact.attributes
    attrs.groupName = app.models.groups.get(attrs.groupId).get('name')
    attrs.id = contact.id || contact.cid
    attrs.groups = app.models.groups.makeOptions contact.get 'groupId'
    @template attrs

  renderAll: ->
    @$el.html @collection.map(@renderOne).join("")
    @updateSelects()

  updateSelects: ->
    @$(".col.js-group select").selectpicker(
      container: 'body'
    ).selectpicker('setStyle', 'form-control group-select-ui')

  filterOut: (query) ->
    @query = _.trim(query.toLowerCase())
    $rows = @$el.find('.row').show()
    if @query
      toHide = @collection.filter (contact) =>
        for subQuery in @query.split(" ")
          found = _.str.include(contact.get('name').toLowerCase(), subQuery) or
            _.str.include(contact.get('phone').toLowerCase(), subQuery)
          return false if found
        return true
      ids = _.map(toHide, (contact) -> "#contact-#{contact.id}").join(", ")
      $rows.filter(ids).hide()


  render: ->
    if @collection.notNew().length > 0
      @renderAll()
    else
      @$el.html "<span class='no-data'>There is no contacts yet. <strong>Add one!</strong></span>"


class app.views.MainPage extends Backbone.View
  el: '#main-page-content'

  errorTemplate: _.template $("#error-message-box").html()

  events: ->
    'click #top-form button.cancel': => @searchForm.render()
    'click #top-form button.add-one': => @addForm.render()

  initialize: ->
    @addForm = new app.views.AddForm()
    @addForm.on 'done', => @searchForm.render()
    @searchForm = new app.views.SearchForm()
    @contactsListView = new app.views.ContactsListView()

  render: ->
    @$(".alert").alert()
    @searchForm.render()
    @contactsListView.render()

  showError: (msg) ->
    $("#alerts-box").html @errorTemplate message: msg

  closeError: ->
    @$("button.close").click()

  filter: (query) ->
    @contactsListView.filterOut query
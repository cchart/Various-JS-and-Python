class app.views.SearchForm extends Backbone.View
  el: '#top-form'

  events:
    'keydown #search-add-field': 'search'

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
    @$(".second-row").slideUp()

  search: ->

class app.views.AddForm extends Backbone.View
  el: '#top-form'

  events:
    'click button.cancel': 'cancel'
    'click button.save': 'save'
    'keyup input': 'clearErorrs'

  initialize: ->
    _.bindAll @, 'renderGroups'
    @$name = $ '#search-add-field'
    @$phone = $ '#phone-field'
    @$group = $ '#group-field'
    @$searchAddIcon = @$ "label[for=search-add-field] i"
    @resetModel()
    @model.on 'invalid', (a,b) =>
      console.log a,b,@model.validationError
      [fields, message] = @model.validationError
      for field in fields
        @$("[data-field=#{field}]").parent().addClass('has-error')
      app.mainPage.showError message

    app.models.groups.on 'all', @renderGroups

  renderGroups: ->
    @$group.html app.models.groups.makeOptions()

  resetModel: ->
    @model = new app.models.Contact()

  cancel: ->
    @$name.val ""
    @$phone.val ""

  clearErorrs: (e) ->
    ($ e.target).parents('.has-error').removeClass 'has-error'
    app.mainPage.closeError()

  save: ->
    @model.set
      name: @$name.val()
      phone: @$phone.val()
      groupId: @$group.val()

    if @model.isValid()
      app.models.contacts.create @model
      @model.save()
      @trigger 'done'
      console.log("ok")

  render: ->
    @$name.attr 'placeholder', 'Full name'
    @$searchAddIcon.removeAttr('class').addClass 'icon-user'
    @$el.addClass 'add-form-state'
    @$('.has-error').removeClass 'has-error'
    app.mainPage.closeError()
    @$name.focus()
    @renderGroups()
    @$(".second-row").slideDown()

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

  collection: app.models.contacts

  template: _.template $("#contact-list-item").html()

  initialize: ->
    _.bindAll @, 'renderAll', 'renderOne', 'deleteOne', 'changeOne'
    @collection.on 'reset add', @renderAll
    @collection.on 'delete', @deleteOne
    @collection.on 'change', @changeOne
    @collection.fetch()

  deleteOne: (contact) ->
    $row = $("#contact-#{contact.id}")
    $row.slideUp()
    setTimeout (-> $row.remove()), 1000

  changeOne: (contact) ->
    $row = $("#contact-#{contact.id}")
    $row.replaceWith @renderOne contact
    @updateSelects()

  getRow: (e) -> ($ e.currentTarget).parents('.row:eq(0)')

  getContactOnEvent: (e) ->
    $row = @getRow e
    id = $row.data 'id'
    @collection.get id

  editMode: (e) ->
    $row = @getRow e
    return if $row.is '.edit-mode'
    $row.addClass 'edit-mode'

  cancelRow: (e) ->
    $row = @getRow e
    $row.removeClass 'edit-mode'

  clickDelete: (e) ->
    @deleteOne @getContactOnEvent e #TODO delete from collection

  saveRow: (e) ->
    $row = @getRow e
    contact = @getContactOnEvent e
    contact.save
      name: $row.find(".js-name input").val()
      phone: $row.find(".js-phone input").val()
      groupId: $row.find(".js-group select").val()

  renderOne: (contact) ->
    attrs = _.clone contact.attributes
    attrs.groupName = app.models.groups.get(attrs.groupId).get('name')
    attrs.id = contact.id
    attrs.groups = app.models.groups.makeOptions()
    @template attrs

  renderAll: ->
    @$el.html @collection.map(@renderOne).join("")
    @updateSelects()

  updateSelects: ->
    @$(".col.js-group select").selectpicker(
      container: 'body'
    ).selectpicker('setStyle', 'form-control group-select-ui')

  render: ->
    if @collection.length > 0
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